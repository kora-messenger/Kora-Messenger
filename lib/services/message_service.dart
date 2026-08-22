import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_models.dart';
import 'connectivity_service.dart';
import 'offline_voice_sync.dart';

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

  Future<void> _persist(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = _cache[chatId] ?? [];
    await prefs.setString(
      '$_kPrefix$chatId',
      jsonEncode(msgs.map((m) => m.toJson()).toList()),
    );
  }

  // ── Send / React / Delete ─────────────────────────────────

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
    String? replyToText,
    String? replyToName,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    messages.add(KoraMessage(
      id: msgId,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    ));
    await _persist(chatId);

    // Auto-progress: sent → delivered (1.5s) → read (4s)
    // Simulates recipient receiving and reading the message
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final msgs = _cache[chatId];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m.id == msgId);
      if (idx != -1 && msgs[idx].status == MessageStatus.sent) {
        msgs[idx] = msgs[idx].copyWith(status: MessageStatus.delivered);
        await _persist(chatId);
      }
    });

    Future.delayed(const Duration(seconds: 4), () async {
      final msgs = _cache[chatId];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m.id == msgId);
      if (idx != -1 && msgs[idx].status == MessageStatus.delivered) {
        msgs[idx] = msgs[idx].copyWith(status: MessageStatus.read);
        await _persist(chatId);
      }
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
    messages.add(KoraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    ));
    await _persist(chatId);
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

  Future<void> sendVoiceMessage(String chatId, String duration, {
    String? filePath,
    String? transcript,
  }) async {
    final messages = _cache.putIfAbsent(chatId, () => <KoraMessage>[]);
    final msgId = 'voice_${DateTime.now().millisecondsSinceEpoch}';

    // Check connectivity — if offline, save as pending and enqueue for sync
    final isOnline = ConnectivityService.instance.isOnline;

    final status = isOnline ? MessageStatus.sent : MessageStatus.pendingOffline;

    messages.add(KoraMessage(
      id: msgId,
      text: '',
      timestamp: DateTime.now(),
      isMe: true,
      type: KoraMessageType.voice,
      status: status,
      voiceDuration: duration,
      voiceFilePath: filePath,
      voiceTransferState:
          isOnline ? VoiceTransferState.uploading : VoiceTransferState.notSent,
      voiceTranscript: transcript,
    ));
    await _persist(chatId);

    if (!isOnline) {
      // Enqueue for automatic sync when network returns
      await OfflineVoiceSyncService.instance.enqueue(
        chatId: chatId,
        messageId: msgId,
        duration: duration,
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
  /// message that was sent while online.
  void _scheduleVoiceStatusProgress(String chatId, String msgId) {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final msgs = _cache[chatId];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m.id == msgId);
      if (idx != -1 && msgs[idx].status == MessageStatus.sent) {
        msgs[idx] = msgs[idx].copyWith(status: MessageStatus.delivered);
        await _persist(chatId);
      }
    });

    Future.delayed(const Duration(seconds: 4), () async {
      final msgs = _cache[chatId];
      if (msgs == null) return;
      final idx = msgs.indexWhere((m) => m.id == msgId);
      if (idx != -1 && msgs[idx].status == MessageStatus.delivered) {
        msgs[idx] = msgs[idx].copyWith(status: MessageStatus.read);
        await _persist(chatId);
      }
    });
  }

  Future<void> toggleReaction(String chatId, String messageId, String emoji) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = messages[idx];
    messages[idx] = msg.copyWith(reaction: msg.reaction == emoji ? null : emoji);
    await _persist(chatId);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final messages = _cache[chatId];
    if (messages == null) return;
    messages.removeWhere((m) => m.id == messageId);
    await _persist(chatId);
    // Also remove from offline sync queue if present
    await OfflineVoiceSyncService.instance.removePending(chatId, messageId);
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
    _cache['kora_support'] = [
      KoraMessage(
        id: 'welcome_1',
        text: 'Welcome to Kora Messenger! 🎉\n\n'
            'Congratulations — you\'ve been given 7 days of Kora Premium for free!\n\n'
            'With Premium you get: custom app icons, premium wallpapers, '
            'custom chat bubbles, animated emoji, real-time translation, '
            'infinite reactions, faster download speeds, a profile badge, '
            'priority support, and no ads.\n\n'
            'Your free Premium trial will expire in 7 days. '
            'Enjoy! ✨',
        timestamp: now,
        isMe: false,
        isAi: true,
        status: MessageStatus.none,
      ),
    ];
    _persist('kora_support');
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
}
