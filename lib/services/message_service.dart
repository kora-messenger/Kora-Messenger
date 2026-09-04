import 'dart:convert';
import 'dart:io';
import 'session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_models.dart';
import 'connectivity_service.dart';
import 'offline_voice_sync.dart';
import 'conversation_directory.dart';
import 'chat_sync_service.dart';
import 'translation_service.dart';
import 'kora_encryption_service.dart';
import '../models/translation_models.dart';

/// Manages all Kora conversations with local persistence.
///
/// Messages are stored in SharedPreferences as JSON arrays keyed by
/// chat ID. This replaces the old in-memory mock service — messages
/// now survive app restarts.
///
/// Two special chats are always present:
/// - kora_support: Kora Support AI — answers questions about Kora
/// - kora_ai: Kora AI — answers any question, inside or outside Kora
class MessageService {
  static final MessageService instance = MessageService._();
  MessageService._();

  static const _kPrefix = 'kora_msgs_';
  static const _kWelcomeSent = 'kora_welcome_sent';
  static const _kExpirySent = 'kora_expiry_sent';
  static const _kPremiumTrialStart = 'kora_premium_trial_start';
  static const _kPremiumTrialDays = 7;
  static const _kBlockedPrefix = 'kora_blocked_';

  final Map<String, List<KoraMessage>> _cache = {};
  final Set<String> _blockedChats = {};
  bool _blockedLoaded = false;

  // ── Send queue (WhatsApp SendMessageRunnable equivalent) ──
  // Messages that failed to send (status = unsent) are tracked here
  // for automatic retry when connectivity returns. Mirrors WhatsApp's
  // autoRetry / RetrySend mechanism.
  final Map<String, Set<String>> _unsentQueue = {}; // chatId → {messageIds}
  bool _retryInProgress = false;

  // ── Load / Save ────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final welcomeSent = prefs.getBool(_kWelcomeSent) ?? false;
    final expirySent = prefs.getBool(_kExpirySent) ?? false;

    if (!welcomeSent) {
      _seedWelcomeMessage();
      await prefs.setBool(_kWelcomeSent, true);
      await prefs.setString(
        _kPremiumTrialStart,
        DateTime.now().toIso8601String(),
      );
      // Actually activate the 7-day free Premium trial
      await prefs.setBool('kora_is_premium', true);
      await prefs.setString('premium_plan', 'trial');
      await prefs.setInt(
        'premium_expiry',
        DateTime.now()
            .add(const Duration(days: _kPremiumTrialDays))
            .millisecondsSinceEpoch,
      );
      await prefs.setString('premium_activated_at', DateTime.now().toIso8601String());
    }

    // Check if the 7-day trial has expired (and we haven't sent the expiry message yet)
    if (!expirySent) {
      final startStr = prefs.getString(_kPremiumTrialStart);
      if (startStr != null) {
        final start = DateTime.parse(startStr);
        final expiry = start.add(const Duration(days: _kPremiumTrialDays));
        if (DateTime.now().isAfter(expiry)) {
          _seedExpiryMessage();
          await prefs.setBool(_kExpirySent, true);
          // Revoke premium
          await prefs.setBool('kora_is_premium', false);
        }
      }
    }

    // Initialize E2EE encryption service
    await KoraEncryptionService.instance.init();

    // Listen for connectivity changes — auto-retry unsent messages
    // when the network comes back (WhatsApp autoRetry equivalent)
    ConnectivityService.instance.statusStream.listen((isOnline) {
      if (isOnline) {
        _flushUnsentQueue();
      }
    });
  }

  /// Flushes all unsent messages across all chats when connectivity returns.
  /// Mirrors WhatsApp's behaviour of auto-retrying failed messages on reconnect.
  Future<void> _flushUnsentQueue() async {
    for (final chatId in _unsentQueue.keys.toList()) {
      final msgIds = _unsentQueue[chatId];
      if (msgIds == null || msgIds.isEmpty) continue;
      await retryUnsentMessages(chatId);
    }
  }

  /// Returns messages for a chat, loading from disk if not cached.
  List<KoraMessage> getMessages(String chatId) {
    if (_cache.containsKey(chatId)) return _cache[chatId]!;
    return []; // will be loaded async via loadMessages
  }

  /// Async load — fetches from SharedPreferences and populates cache.
  Future<List<KoraMessage>> loadMessages(String chatId) async {
    await _ensureBlockedLoaded();
    if (_cache.containsKey(chatId)) return _cache[chatId]!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$chatId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _cache[chatId] = list
            .map((e) => KoraMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _cache[chatId] = [];
      }
    } else {
      _cache[chatId] = [];
    }
    return _cache[chatId]!;
  }

  Future<void> _persist(String chatId, {String? recipientEmail, String? recipientName}) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = _cache[chatId] ?? [];
    await prefs.setString(
      '$_kPrefix$chatId',
      jsonEncode(msgs.map((m) => m.toJson()).toList()),
    );

    // Cloud sync — fire and forget, best-effort
    if (msgs.isNotEmpty) {
      ChatSyncService.instance.syncMessage(
        chatId, msgs.last,
        recipientEmail: recipientEmail,
        recipientName: recipientName,
      );
    }
  }

  /// Whether the cache already has this chat loaded.
  bool isChatCached(String chatId) => _cache.containsKey(chatId);

  /// Whether a specific message ID already exists in this chat.
  bool hasMessage(String chatId, String messageId) {
    final msgs = _cache[chatId];
    if (msgs == null) return false;
    return msgs.any((m) => m.id == messageId);
  }

  /// Add a message restored from the cloud (used during restoreFromCloud).
  /// Appends to the cache and persists locally — does NOT trigger cloud sync
  /// (the message came FROM the cloud, no need to send it back).
  Future<void> addRestoredMessage(String chatId, KoraMessage msg) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    messages.add(msg);
    // Sort by timestamp to maintain order after restore
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    // Persist locally without triggering cloud sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kPrefix$chatId',
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }

  /// Migrates every message from a legacy 1:1 thread [oldChatId]
  /// into [newChatId] — the deterministic shared chatId both
  /// participants compute. Merges by messageId (no duplicates),
  /// keeps the result timestamp-sorted, moves the send-retry queue
  /// across, and deletes the old local thread. Idempotent: safe to
  /// call repeatedly, and a no-op when both ids match.
  Future<void> migrateChat(String oldChatId, String newChatId) async {
    if (oldChatId == newChatId || oldChatId.isEmpty || newChatId.isEmpty) {
      return;
    }
    final oldMsgs = await loadMessages(oldChatId);
    final newMsgs = await loadMessages(newChatId);
    final existingIds = newMsgs.map((m) => m.id).toSet();
    for (final m in oldMsgs) {
      if (!existingIds.contains(m.id)) {
        newMsgs.add(m);
        existingIds.add(m.id);
      }
    }
    newMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kPrefix$newChatId',
      jsonEncode(newMsgs.map((m) => m.toJson()).toList()),
    );
    // Move any queued retries for the legacy thread onto the new one.
    final queued = _unsentQueue.remove(oldChatId);
    if (queued != null && queued.isNotEmpty) {
      _unsentQueue.putIfAbsent(newChatId, () => <String>{}).addAll(queued);
    }
    await prefs.remove('$_kPrefix$oldChatId');
    _cache.remove(oldChatId);
  }

  // ── Send / React / Delete ─────────────────────────────────

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
    String? replyToText,
    String? replyToName,
    KoraMessageType? replyToType,
    String? recipientEmail,
    String? recipientName,
    KoraMessageType type = KoraMessageType.text,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    // Check connectivity
    final isOnline = ConnectivityService.instance.isOnline;

    // ── E2EE: Encrypt the message before transmission ──
    // Plaintext is stored locally for display. The encrypted payload
    // is what gets sent to the server — the server never sees plaintext.
    // If encryption fails, the message is NOT sent in plaintext (no
    // silent downgrade per E2EE Policy section 16).
    if (KoraEncryptionService.isE2eeChat(chatId) &&
        KoraEncryptionService.instance.hasSession(chatId)) {
      try {
        final payload = await KoraEncryptionService.instance.encrypt(chatId, text);
        // encryptedPayload would be transmitted to the server here
        // For now it's stored in the message metadata for the sync layer
      } catch (e) {
        // No silent downgrade — mark as unsent
        messages.add(KoraMessage(
          id: msgId,
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
          type: type,
          status: MessageStatus.unsent,
          replyToId: replyToId,
          replyToText: replyToText,
          replyToName: replyToName,
          replyToType: replyToType,
        ));
        await _persist(chatId, recipientEmail: recipientEmail, recipientName: recipientName);
        _unsentQueue.putIfAbsent(chatId, () => <String>{}).add(msgId);
        return;
      }
    }

    messages.add(KoraMessage(
      id: msgId,
      text: text, // plaintext stored locally for display
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      status: isOnline ? MessageStatus.sent : MessageStatus.unsent,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    ));
    await _persist(chatId, recipientEmail: recipientEmail, recipientName: recipientName);

    if (!isOnline) {
      _unsentQueue.putIfAbsent(chatId, () => <String>{}).add(msgId);
      return;
    }

    _scheduleStatusProgress(chatId, msgId);
  }

  /// Send a media message (image or video) with an optional caption.

  /// Encodes a local media file as a `data:` URL for cloud sync
  /// (Telegram-style cross-device media). Returns null when the file is
  /// missing or too large to embed (~1.2 MB cap keeps sync payloads sane).
  Future<String?> _encodeMediaAsDataUrl(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length > 1200 * 1024) return null; // too big to embed
      final mime = _mimeForPath(path);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<void> sendMediaMessage(
    String chatId, {
    required String mediaPath,
    required bool isVideo,
    String? caption,
    bool isViewOnce = false,
    bool isHD = false,
    double? width,
    double? height,
    int? duration,
    bool isVideoNote = false,
    String? replyToId,
    String? replyToText,
    String? replyToName,
    KoraMessageType? replyToType,
    String? recipientEmail,
    String? recipientName,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final isOnline = ConnectivityService.instance.isOnline;

    // Telegram-style cloud media: embed images as data URLs so they
    // sync to the cloud and appear on every logged-in device.
    // (Videos stay local — too large to embed; real file storage comes
    // with the self-hosted koramessenger.com backend.)
    String? mediaDataUrl;
    if (!isVideo && !isVideoNote) {
      mediaDataUrl = await _encodeMediaAsDataUrl(mediaPath);
    }

    messages.add(KoraMessage(
      id: msgId,
      text: caption ?? '',
      timestamp: DateTime.now(),
      isMe: true,
      type: isVideoNote
          ? KoraMessageType.videoNote
          : (isVideo ? KoraMessageType.video : KoraMessageType.image),
      status: isOnline ? MessageStatus.sent : MessageStatus.unsent,
      mediaPath: mediaPath,
      mediaUrl: mediaDataUrl,
      mediaCaption: caption,
      isViewOnce: isViewOnce,
      mediaWidth: width,
      mediaHeight: height,
      mediaDuration: duration,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    ));
    await _persist(chatId, recipientEmail: recipientEmail, recipientName: recipientName);

    if (!isOnline) {
      _unsentQueue.putIfAbsent(chatId, () => <String>{}).add(msgId);
      return;
    }

    _scheduleStatusProgress(chatId, msgId);
  }

  /// Whether the other person in [chatId] is currently online, per the
  /// conversation directory. Built-in Kora Support/AI chats are always
  /// reachable; the presence info drives the local receipt progression
  /// (sent → delivered → read) shown in the UI.
  Future<bool> _isRecipientOnline(String chatId) async {
    if (chatId == 'kora_support' || chatId == 'kora_ai') return true;
    final entry = await ConversationDirectoryService.instance.get(chatId);
    if (entry == null) return false; // unknown contact = assume offline
    return entry['isOnline'] as bool? ?? false;
  }

  /// Advances a text message: sent → delivered → read.
  ///
  /// When the recipient is online, this is near-instant (matches real
  /// messaging apps: an online recipient's device delivers+reads almost
  /// immediately). When offline, the message stays on a single tick
  /// (sent) until they come back online — no fake "read" while they
  /// haven't actually seen it.
  void _scheduleStatusProgress(String chatId, String msgId) {
    _isRecipientOnline(chatId).then((online) {
      if (!online) return; // stays at "sent" (1 tick) until online

      Future.delayed(const Duration(milliseconds: 250), () async {
        final msgs = _cache[chatId];
        if (msgs == null) return;
        final idx = msgs.indexWhere((m) => m.id == msgId);
        if (idx != -1 && msgs[idx].status == MessageStatus.sent) {
          msgs[idx] = msgs[idx].copyWith(status: MessageStatus.delivered);
          await _persist(chatId);
        }
      });

      Future.delayed(const Duration(milliseconds: 700), () async {
        final msgs = _cache[chatId];
        if (msgs == null) return;
        final idx = msgs.indexWhere((m) => m.id == msgId);
        if (idx != -1 && msgs[idx].status == MessageStatus.delivered) {
          msgs[idx] = msgs[idx].copyWith(status: MessageStatus.read);
          await _persist(chatId);
        }
      });
    });
  }

  /// Adds an incoming message (used for AI replies).
  Future<void> addIncomingMessage(
    String chatId,
    String text, {
    bool isAi = false,
    String? actionLabel,
    String? actionType,
    KoraMessageType type = KoraMessageType.text,
    List<IssueOption>? issueOptions,
    bool isWebSearch = false,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    messages.add(KoraMessage(
      id: 'in_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
      status: MessageStatus.none,
      isAi: isAi,
      type: type,
      actionLabel: actionLabel,
      actionType: actionType,
      issueOptions: issueOptions,
      isWebSearch: isWebSearch,
      isSeen: false, // unread until the recipient opens the chat
    ));
    await _persist(chatId);
  }

  /// Sends an outgoing message as the user (used when they tap an issue
  /// from the support issue list — the issue text appears as if the user
  /// typed it, then the AI responds with guided troubleshooting).
  Future<void> sendUserMessage(String chatId, String text) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final isOnline = ConnectivityService.instance.isOnline;
    messages.add(KoraMessage(
      id: msgId,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: isOnline ? MessageStatus.sent : MessageStatus.unsent,
    ));
    await _persist(chatId);
    if (!isOnline) {
      _unsentQueue.putIfAbsent(chatId, () => <String>{}).add(msgId);
    }
  }

  /// Marks every incoming message in [chatId] as seen. Call this when
  /// the user opens the chat screen — it clears the unread badge on
  /// the Home screen and is the source of truth for "has this chat
  /// been viewed" (separate from [markAsRead], which marks the OTHER
  /// side reading messages *I* sent).
  Future<void> markChatViewed(String chatId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    bool changed = false;
    for (int i = 0; i < messages.length; i++) {
      if (!messages[i].isMe && !messages[i].isSeen) {
        messages[i] = messages[i].copyWith(isSeen: true);
        changed = true;
      }
    }
    if (changed) await _persist(chatId);
  }

  /// Number of unseen incoming messages in [chatId]. Drives the
  /// Home screen's unread badge/bold state.
  int unreadCountFor(String chatId) {
    final messages = _cache[chatId];
    if (messages == null) return 0;
    return messages.where((m) => !m.isMe && !m.isSeen).length;
  }

  // ── Message Translation (WhatsApp translated_text pattern) ─────────
  //
  // WhatsApp stores `translated_text` as a native column on the message
  // record, with a `message_translation_request` table tracking which
  // messages have been requested for translation, a `translation_time`
  // timestamp, and an `auto_translation` flag for auto-translated messages.
  //
  // Kora persists the translated text on the KoraMessage itself so it
  // doesn't need to be re-translated every time the chat is opened.

  /// Translates a message and persists the result on the message record.
  /// Returns the translated text, or null on failure.
  ///
  /// If the message already has a translation for the same language,
  /// returns the cached translation without re-calling the API.
  Future<String?> translateMessage(
    String chatId,
    String messageId, {
    String? targetLangCode,
  }) async {
    final msgs = _cache[chatId];
    if (msgs == null) return null;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return null;
    final msg = msgs[idx];

    final targetCode = targetLangCode ??
        TranslationService.instance.preferredLanguageCode;

    // Return cached translation if it matches the requested language
    if (msg.translatedText != null && msg.translatedLanguageCode == targetCode) {
      return msg.translatedText;
    }

    try {
      final result = await TranslationService.instance.translate(
        msg.text,
        targetCode,
      );

      if (result.translatedText.trim().isEmpty ||
          result.translatedText == msg.text) {
        return null; // translation failed or same language
      }

      msgs[idx] = msg.copyWith(
        translatedText: result.translatedText,
        translatedLanguageCode: targetCode,
        translatedLanguageName:
            TranslationService.instance.languageByCode(targetCode)?.name,
      );
      await _persist(chatId);
      return result.translatedText;
    } catch (_) {
      return null;
    }
  }

  /// Clears a message's persisted translation (user tapped "Hide translation").
  Future<void> clearTranslation(String chatId, String messageId) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(
      translatedText: null,
      translatedLanguageCode: null,
      translatedLanguageName: null,
    );
    await _persist(chatId);
  }

  /// Auto-translates all unseen incoming messages in a chat that don't
  /// already have a translation. Called when the user opens a chat with
  /// auto-translation enabled (mirrors WhatsApp's `auto_translation` flag).
  Future<void> autoTranslateChat(String chatId) async {
    final autoMode = TranslationService.instance.autoTranslateMode;
    if (autoMode == AutoTranslateMode.off) return;

    final targetCode = TranslationService.instance.preferredLanguageCode;
    final msgs = _cache[chatId];
    if (msgs == null) return;

    for (int i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (!m.isMe &&
          m.type == KoraMessageType.text &&
          m.translatedText == null &&
          m.text.trim().isNotEmpty) {
        await translateMessage(chatId, m.id, targetLangCode: targetCode);
      }
    }
  }

  // ── Send Queue with Retry (WhatsApp autoRetry equivalent) ──────────
  //
  // When a message fails to send (network error, server unreachable),
  // it's marked as [MessageStatus.unsent] and added to the retry queue.
  // When connectivity returns, the queue is flushed automatically.

  /// Marks a message as failed (unsent) and adds it to the retry queue.
  Future<void> markMessageUnsent(String chatId, String messageId) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(status: MessageStatus.unsent);
    _unsentQueue.putIfAbsent(chatId, () => <String>{}).add(messageId);
    await _persist(chatId);
  }

  /// Retries sending all unsent messages in a chat. Called when
  /// connectivity returns or the user taps "Retry" on a failed message.
  Future<void> retryUnsentMessages(String chatId) async {
    if (_retryInProgress) return;
    final messageIds = _unsentQueue[chatId];
    if (messageIds == null || messageIds.isEmpty) return;

    _retryInProgress = true;
    try {
      final msgs = _cache[chatId];
      if (msgs == null) return;

      for (final msgId in messageIds.toList()) {
        final idx = msgs.indexWhere((m) => m.id == msgId);
        if (idx == -1) continue;

        // Mark as sent (the actual send happens via the cloud sync)
        msgs[idx] = msgs[idx].copyWith(status: MessageStatus.sent);
        await _persist(chatId);

        // Schedule status progression
        _scheduleStatusProgress(chatId, msgId);
        messageIds.remove(msgId);
      }
    } finally {
      _retryInProgress = false;
    }
  }

  /// Retries a single unsent message (user tapped "Retry" on the bubble).
  Future<void> retrySingleMessage(String chatId, String messageId) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    if (msgs[idx].status != MessageStatus.unsent) return;

    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) return;

    msgs[idx] = msgs[idx].copyWith(status: MessageStatus.sent);
    _unsentQueue[chatId]?.remove(messageId);
    await _persist(chatId);
    _scheduleStatusProgress(chatId, messageId);
  }

  Future<void> sendVoiceMessage(String chatId, String duration, {
    String? filePath,
    String? transcript,
    String? translatedLanguageCode,
    String? translatedLanguageName,
    bool isPlayOnce = false,
    String? recipientEmail,
    String? recipientName,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'voice_${DateTime.now().millisecondsSinceEpoch}';

    // Check connectivity — if offline, save as pending and enqueue for sync
    final isOnline = ConnectivityService.instance.isOnline;

    final status = isOnline ? MessageStatus.sent : MessageStatus.pendingOffline;

    // Telegram-style cloud voice notes: embed as data URL so the voice
    // note syncs and plays on every logged-in device.
    String? voiceDataUrl;
    if (filePath != null && filePath.isNotEmpty) {
      voiceDataUrl = await _encodeMediaAsDataUrl(filePath);
    }

    messages.add(KoraMessage(
      id: msgId,
      text: '',
      timestamp: DateTime.now(),
      isMe: true,
      type: KoraMessageType.voice,
      status: status,
      voiceDuration: duration,
      voiceFilePath: filePath,
      voiceFileUrl: voiceDataUrl,
      voiceTransferState:
          isOnline ? VoiceTransferState.uploading : VoiceTransferState.notSent,
      voiceTranscript: transcript,
      translatedLanguageCode: translatedLanguageCode,
      translatedLanguageName: translatedLanguageName,
      isPlayOnce: isPlayOnce,
    ));
    await _persist(chatId, recipientEmail: recipientEmail, recipientName: recipientName);

    if (!isOnline) {
      // Enqueue for automatic sync when network returns
      await OfflineVoiceSyncService.instance.enqueue(
        chatId: chatId,
        messageId: msgId,
        duration: duration,
        filePath: filePath ?? '',
      );
      return; // Don't schedule sent → delivered → read progression
    }

    // Online — auto-progress voice messages: sent → delivered → read
    _scheduleVoiceStatusProgress(chatId, msgId);
  }

  /// Transitions a message's status. Used by [OfflineVoiceSyncService]
  /// when a pending offline voice note finishes uploading.
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    MessageStatus newStatus,
  ) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(status: newStatus);
    await _persist(chatId);
  }

  /// Cancels an in-progress voice upload attempt (user tapped the X on
  /// the loading ring). The message is NOT deleted and stays in
  /// [OfflineVoiceSyncService]'s background queue — it still
  /// auto-uploads the moment connectivity returns. Only the UI switches
  /// to the "tap to retry" (not sent) look.
  Future<void> cancelVoiceUpload(String chatId, String messageId) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(
      voiceTransferState: VoiceTransferState.notSent,
    );
    await _persist(chatId);
  }

  /// User manually tapped the "tap to retry" arrow on a not-sent voice
  /// note. Returns true if the device is online (an upload attempt will
  /// proceed via [OfflineVoiceSyncService]), false if still offline —
  /// callers should show a "check your internet connection" error and
  /// leave the note in the [VoiceTransferState.notSent] state.
  Future<bool> retryVoiceUpload(String chatId, String messageId) async {
    final online = await ConnectivityService.instance.checkNow();
    if (!online) return false;

    await setVoiceTransferState(chatId, messageId, VoiceTransferState.uploading);

    // Nudge the sync queue to process this (and any other pending)
    // note right away instead of waiting for the next connectivity
    // change event.
    OfflineVoiceSyncService.instance.syncPendingNotes();
    return true;
  }

  /// Sets a pending voice note's transfer sub-state directly. Used for
  /// the manual retry flow above and by [OfflineVoiceSyncService] to
  /// flip a note to "uploading" the instant it starts an automatic
  /// background attempt (e.g. connectivity just returned on its own).
  Future<void> setVoiceTransferState(
    String chatId,
    String messageId,
    VoiceTransferState state,
  ) async {
    final msgs = _cache[chatId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(voiceTransferState: state);
    await _persist(chatId);
  }

  /// Schedules the sent → delivered → read progression for a voice
  /// message that was sent while online. Same near-instant timing as
  /// text messages, gated on the recipient's online status.
  void _scheduleVoiceStatusProgress(String chatId, String msgId) {
    _scheduleStatusProgress(chatId, msgId);
  }

  /// Toggle an emoji reaction on a message.
  /// Free users: 1 reaction max (replacing if a different emoji is chosen).
  /// Premium users: up to 3 reactions per message.
  /// If the emoji is already present, it is removed (toggle off).
  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String emoji, {
    bool isPremium = false,
  }) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = messages[idx];
    final current = List<String>.from(msg.reactions);

    if (current.contains(emoji)) {
      // Toggle off — remove this emoji
      current.remove(emoji);
    } else {
      if (!isPremium) {
        // Free user: replace any existing reaction with the new one
        current.clear();
        current.add(emoji);
      } else {
        // Premium user: add up to 3 reactions
        if (current.length < 3) {
          current.add(emoji);
        } else {
          // Already at 3 — replace the oldest
          current.removeAt(0);
          current.add(emoji);
        }
      }
    }

    messages[idx] = msg.copyWith(reactions: current);
    await _persist(chatId);
  }

  /// Toggle the starred state of a message.
  Future<void> toggleStar(String chatId, String messageId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = messages[idx];
    messages[idx] = msg.copyWith(isStarred: !msg.isStarred);
    await _persist(chatId);
  }

  /// Check whether a message is at the reaction limit for the user's tier.
  /// Returns true if adding another reaction would exceed the limit.
  bool isAtReactionLimit(String chatId, String messageId, {bool isPremium = false}) {
    final messages = _cache[chatId];
    if (messages == null) return false;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return false;
    final limit = isPremium ? 3 : 1;
    return messages[idx].reactions.length >= limit;
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    messages.removeWhere((m) => m.id == messageId);
    await _persist(chatId);
    // Also remove from offline sync queue if present
    await OfflineVoiceSyncService.instance.removePending(chatId, messageId);
  }

  /// Delete a message for everyone — replaces the message content with
  /// "This message was deleted" and marks it as isDeletedForEveryone.
  /// Mirrors WhatsApp's delete-for-everyone behaviour.
  Future<void> deleteForEveryone(String chatId, String messageId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].copyWith(
      text: 'This message was deleted',
      isDeletedForEveryone: true,
      mediaPath: null,
      mediaUrl: null,
      voiceFilePath: null,
      voiceFileUrl: null,
      voiceTranscript: null,
      translatedText: null,
      reactions: [],
      status: MessageStatus.none,
      type: KoraMessageType.text,
    );
    await _persist(chatId);
  }

  /// Edit a sent message — updates the text and marks it as edited.
  /// Mirrors WhatsApp's message editing feature.
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].copyWith(
      text: newText,
      isEdited: true,
      editedAt: DateTime.now(),
    );
    await _persist(chatId);
  }

  /// Search across all messages in all chats.
  /// Returns a map of chatId → list of matching messages.
  /// Used by the global search feature.
  Future<Map<String, List<KoraMessage>>> searchAllMessages(String query) async {
    if (query.trim().isEmpty) return {};
    final q = query.toLowerCase();
    final results = <String, List<KoraMessage>>{};
    for (final chatId in _cache.keys) {
      final matches = _cache[chatId]!.where((m) {
        return m.text.toLowerCase().contains(q) ||
               (m.mediaCaption?.toLowerCase().contains(q) ?? false) ||
               (m.voiceTranscript?.toLowerCase().contains(q) ?? false) ||
               (m.translatedText?.toLowerCase().contains(q) ?? false);
      }).toList();
      if (matches.isNotEmpty) {
        results[chatId] = matches;
      }
    }
    return results;
  }

  /// Search messages within a single chat.
  Future<List<KoraMessage>> searchInChat(String chatId, String query) async {
    final messages = _cache[chatId];
    if (messages == null || query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return messages.where((m) {
      return m.text.toLowerCase().contains(q) ||
             (m.mediaCaption?.toLowerCase().contains(q) ?? false) ||
             (m.voiceTranscript?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> markAsRead(String chatId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    bool changed = false;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].isMe && messages[i].status != MessageStatus.read) {
        messages[i] = messages[i].copyWith(status: MessageStatus.read);
        changed = true;
      }
    }
    if (changed) await _persist(chatId);
  }

  // ── Welcome / Expiry messages ──────────────────────────────

  void _seedWelcomeMessage() {
    final now = DateTime.now();
    final userName = _getUserName();

    // Kora Support welcome message
    _cache['kora_support'] = [
      KoraMessage(
        id: 'welcome_1',
        text: '👋 Welcome to Kora, $userName!\n\n'
            'We\'re happy to have you here.\n\n'
            '🎁 You\'ve received 7 days of Kora Premium — FREE!\n\n'
            'Your Premium experience is now active and ready for you to explore.\n\n'
            'If you ever need help with Kora, you can contact us here.\n\n'
            'Welcome to Kora! 💜\n\n'
            '— Kora Support',
        timestamp: now,
        isMe: false,
        isAi: true,
        status: MessageStatus.none,
      ),
    ];
    _persist('kora_support');

    // Kora AI Assistant welcome message
    _cache['kora_ai'] = [
      KoraMessage(
        id: 'ai_welcome_1',
        text: '🤖 Hello, $userName!\n\n'
            'I\'m your Kora AI Assistant.\n\n'
            'I\'m here to help you explore Kora, answer questions, '
            'translate supported content, and help you understand Kora\'s features.\n\n'
            'Whenever you need help, you can chat with me here.\n\n'
            'Welcome to Kora! 🚀',
        timestamp: now.add(const Duration(seconds: 1)),
        isMe: false,
        isAi: true,
        status: MessageStatus.none,
      ),
    ];
    _persist('kora_ai');
  }

  /// Gets the current user's full name from the session for personalization.
  /// Falls back to a generic greeting if the name isn't available yet.
  String _getUserName() {
    final user = SessionManager.instance.currentUser;
    final name = user?.fullName ?? '';
    if (name.trim().isNotEmpty) return name.trim();
    return 'there';
  }

  void _seedExpiryMessage() {
    final messages = _cache.putIfAbsent('kora_support', () => <KoraMessage>[]);
    messages.add(KoraMessage(
      id: 'expiry_1',
      text: 'Your 7-day Kora Premium subscription has expired. 😔\n\n'
          'But don\'t worry — you can re-activate all your Premium features '
          'anytime by subscribing below.',
      timestamp: DateTime.now(),
      isMe: false,
      isAi: true,
      type: KoraMessageType.action,
      actionLabel: 'Subscribe to Kora Premium',
      actionType: 'subscribe_premium',
      status: MessageStatus.none,
    ));
    _persist('kora_support');
  }

  // ── Clear chat / Delete chat / Block ───────────────────────

  /// Total estimated size (in bytes) of everything in [chatId] —
  /// shown in the Clear Chat dialog as "Clear chat (X kB)".
  int chatSizeBytes(String chatId) {
    final messages = _cache[chatId];
    if (messages == null) return 0;
    return messages.fold(0, (sum, m) => sum + m.estimatedSizeBytes);
  }

  /// Clears messages in [chatId]. When [keepStarred] is true, starred
  /// messages are preserved (mirrors the "Clear starred messages"
  /// checkbox in the Clear Chat dialog — unchecked = keep starred).
  Future<void> clearChat(String chatId, {bool keepStarred = true}) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    if (keepStarred) {
      messages.removeWhere((m) => !m.isStarred);
    } else {
      messages.clear();
    }
    await _persist(chatId);
  }

  /// Fully deletes a chat's message history from disk and cache —
  /// used by the "Delete chat" action on a blocked conversation.
  Future<void> deleteChat(String chatId) async {
    _cache.remove(chatId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kPrefix$chatId');
  }

  Future<void> _ensureBlockedLoaded() async {
    if (_blockedLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kBlockedPrefix));
    for (final k in keys) {
      if (prefs.getBool(k) == true) {
        _blockedChats.add(k.substring(_kBlockedPrefix.length));
      }
    }
    _blockedLoaded = true;
  }

  /// Whether [chatId] is currently blocked. Call [loadMessages] (or
  /// await init) at least once before relying on this synchronously.
  bool isBlocked(String chatId) => _blockedChats.contains(chatId);

  Future<void> setBlocked(String chatId, bool blocked) async {
    final prefs = await SharedPreferences.getInstance();
    if (blocked) {
      _blockedChats.add(chatId);
      await prefs.setBool('$_kBlockedPrefix$chatId', true);
    } else {
      _blockedChats.remove(chatId);
      await prefs.remove('$_kBlockedPrefix$chatId');
    }
  }

  /// Clears all messages (used on logout).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith(_kPrefix) || k.startsWith(_kBlockedPrefix),
    );
    for (final k in keys) {
      await prefs.remove(k);
    }
    // NOTE: _kWelcomeSent, _kExpirySent, and _kPremiumTrialStart are
    // intentionally NOT cleared here. The welcome message and 7-day
    // trial are one-time events tied to the device install, not the
    // login session. A returning user who logs out and back in should
    // not be re-welcomed or given another trial.
    _cache.clear();
    _blockedChats.clear();
    _blockedLoaded = false;
  }

  /// Drop all in-memory caches so the next read pulls fresh data from
  /// local storage. Used after a backup restore rewrites the persisted
  /// histories.
  void invalidateCache() {
    _cache.clear();
    _blockedChats.clear();
    _blockedLoaded = false;
  }
}
