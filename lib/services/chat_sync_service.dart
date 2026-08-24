import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';
import '../models/message_model.dart';
import '../models/chat_models.dart';
import 'message_service.dart';
import 'conversation_directory.dart';
import 'notification_service.dart';

/// Syncs Kora chats and messages to/from the Base44 database.
///
/// On every message send/receive, [syncMessage] pushes it to the backend.
/// On login or app start, [restoreFromCloud] fetches all conversations and
/// messages from the database — so even if the user deletes and reinstalls
/// the app, logging in with the same email restores every chat.
///
/// Also handles periodic polling via [startPolling] to deliver new incoming
/// messages in real-time while the app is active.
class ChatSyncService {
  static final ChatSyncService instance = ChatSyncService._();
  ChatSyncService._();

  String? _userEmail;
  bool _syncing = false;
  bool _restoring = false;
  Timer? _pollTimer;

  /// Callback invoked when new incoming messages are detected via polling.
  VoidCallback? onNewMessages;

  /// Timestamp of the last successful message poll or cloud restore.
  DateTime? lastPollTime;

  /// Set the user's email — called after login.
  void setUserEmail(String email) {
    _userEmail = email;
  }

  String? get userEmail => _userEmail;

  /// Sync a single message to the backend (fire-and-forget).
  String? _senderName;

  /// Set the sender's display name — called after login.
  void setSenderName(String name) {
    _senderName = name;
  }

  String? get senderName => _senderName;

  /// Start periodic polling for incoming messages (every 5 seconds).
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollNewMessages();
    });
  }

  /// Stop periodic polling for incoming messages.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Poll the backend for new incoming messages and conversations.
  Future<void> _pollNewMessages() async {
    if (_userEmail == null || _syncing) return;

    _syncing = true;
    final pollStartTime = DateTime.now();
    final newMessages = <String, List<KoraMessage>>{}; // chatId -> new messages

    try {
      final body = <String, dynamic>{
        'action': 'fetchNew',
        'userEmail': _userEmail,
      };
      if (lastPollTime != null) {
        body['sinceTimestamp'] = lastPollTime!.toIso8601String();
      }

      final response = await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Restore/update conversations in the directory
        final conversations = data['conversations'] as List? ?? [];
        for (final conv in conversations) {
          final chatId = conv['chatId'] as String;
          if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

          await ConversationDirectoryService.instance.upsert(
            chatId: chatId,
            name: conv['name'] as String? ?? chatId,
            avatarAsset: conv['avatarAsset'] as String?,
            avatarUrl: conv['avatarUrl'] as String?,
            recipientEmail: conv['recipientEmail'] as String?,
            badge: KoraBadgeType.values[(conv['badge'] as num?)?.toInt() ?? 0],
            isOnline: (conv['isOnline'] as bool?) ?? false,
          );
        }

        // Restore/append new messages to local storage
        final messages = data['messages'] as List? ?? [];
        final ms = MessageService.instance;

        for (final msg in messages) {
          final chatId = msg['chatId'] as String;
          final messageId = msg['messageId'] as String;

          // Skip AI chat messages — seeded locally, never restore from cloud
          if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

          // Load existing messages for this chat if not cached
          if (!ms.isChatCached(chatId)) {
            await ms.loadMessages(chatId);
          }

          // Check if message already exists locally
          if (ms.hasMessage(chatId, messageId)) continue;

          // Add message from cloud
          final koraMsg = KoraMessage(
            id: messageId,
            text: msg['text'] as String? ?? '',
            timestamp: DateTime.tryParse(msg['timestamp'] as String? ?? '') ?? DateTime.now(),
            isMe: (msg['isMe'] as bool?) ?? false,
            type: _parseType(msg['type'] as String?),
            status: _parseStatus(msg['status'] as String?),
            replyToId: msg['replyToId'] as String?,
            replyToText: msg['replyToText'] as String?,
            replyToName: msg['replyToName'] as String?,
            reaction: msg['reaction'] as String?,
            voiceDuration: msg['voiceDuration'] as String?,
            voiceFilePath: msg['voiceFilePath'] as String?,
            voiceFileUrl: msg['voiceFileUrl'] as String?,
            isVoicePlayed: (msg['isVoicePlayed'] as bool?) ?? false,
            voiceTranscript: msg['voiceTranscript'] as String?,
            translatedLanguageCode: msg['translatedLanguageCode'] as String?,
            translatedLanguageName: msg['translatedLanguageName'] as String?,
            isAi: (msg['isAi'] as bool?) ?? false,
            isWebSearch: (msg['isWebSearch'] as bool?) ?? false,
            isSeen: (msg['isSeen'] as bool?) ?? true,
            isStarred: (msg['isStarred'] as bool?) ?? false,
            actionLabel: msg['actionLabel'] as String?,
            actionType: msg['actionType'] as String?,
          );

          await ms.addRestoredMessage(chatId, koraMsg);

          // Track new incoming (non-self) messages for notifications
          if (!koraMsg.isMe) {
            newMessages.putIfAbsent(chatId, () => []).add(koraMsg);
          }
        }

        lastPollTime = pollStartTime;
      }
    } catch (_) {
      // Best-effort polling fail
    } finally {
      _syncing = false;
    }

    // Fire local notifications for new incoming messages
    if (newMessages.isNotEmpty) {
      // Look up conversation names for notification text
      final directory = await ConversationDirectoryService.instance.getAll();

      for (final entry in newMessages.entries) {
        final chatId = entry.key;
        final msgs = entry.value;
        final meta = directory[chatId];
        final senderName = meta?['name'] as String? ?? 'New message';
        final lastMsg = msgs.last;
        final preview = lastMsg.type == KoraMessageType.voice
            ? 'Voice message'
            : lastMsg.text;

        await KoraNotificationService.instance.showMessageNotification(
          senderName: senderName,
          message: preview,
          chatId: chatId,
        );
      }

      onNewMessages?.call();
    }
  }

  Future<void> syncMessage(String chatId, KoraMessage msg, {
    String? recipientEmail,
    String? recipientName,
  }) async {
    if (_userEmail == null) return;
    if (_restoring) return; // only block during bulk restore, not polling

    try {
      await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'sync',
          'userEmail': _userEmail,
          'recipientEmail': recipientEmail,
          'recipientName': recipientName,
          'senderName': _senderName,
          'messages': [_messageToJson(chatId, msg)],
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Silent fail — local storage is the source of truth,
      // cloud sync is best-effort. Will retry on next message.
    }
  }

  /// Sync a conversation's metadata to the backend.
  Future<void> syncConversation({
    required String chatId,
    required String name,
    String? avatarAsset,
    String? avatarUrl,
    KoraBadgeType badge = KoraBadgeType.none,
    bool isOnline = false,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    String? lastMessageType,
    String? lastVoiceDuration,
    int unreadCount = 0,
    String? recipientEmail,
  }) async {
    if (_userEmail == null) return;

    try {
      await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'sync',
          'userEmail': _userEmail,
          'conversations': [{
            'chatId': chatId,
            'name': name,
            'avatarAsset': avatarAsset,
            'avatarUrl': avatarUrl,
            'badge': badge.index,
            'isOnline': isOnline,
            'recipientEmail': recipientEmail,
            'lastMessageText': lastMessageText ?? '',
            'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'lastMessageType': lastMessageType ?? 'text',
            'lastVoiceDuration': lastVoiceDuration,
            'unreadCount': unreadCount,
          }],
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort.
    }
  }

  /// Restore all conversations and messages from the cloud database.
  /// Called on login or app start — merges cloud data into local storage.
  /// Returns the number of conversations and messages restored.
  Future<({int conversations, int messages})> restoreFromCloud() async {
    if (_userEmail == null) return (conversations: 0, messages: 0);

    _syncing = true;
    _restoring = true;
    int convCount = 0;
    int msgCount = 0;
    final restoreTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'fetch',
          'userEmail': _userEmail,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        _syncing = false;
        return (conversations: 0, messages: 0);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Restore conversations to the directory
      final conversations = data['conversations'] as List? ?? [];
      for (final conv in conversations) {
        final chatId = conv['chatId'] as String;
        if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

        await ConversationDirectoryService.instance.upsert(
          chatId: chatId,
          name: conv['name'] as String? ?? chatId,
          avatarAsset: conv['avatarAsset'] as String?,
          avatarUrl: conv['avatarUrl'] as String?,
          badge: KoraBadgeType.values[(conv['badge'] as num?)?.toInt() ?? 0],
          isOnline: (conv['isOnline'] as bool?) ?? false,
        );
        convCount++;
      }

      // Restore messages to local storage (merge, don't overwrite)
      final messages = data['messages'] as List? ?? [];
      final ms = MessageService.instance;

      for (final msg in messages) {
        final chatId = msg['chatId'] as String;
        final messageId = msg['messageId'] as String;

        // Skip AI chat messages — they're seeded locally by MessageService.init()
        // and should never be re-introduced from the cloud with stale isSeen state.
        if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

        // Load existing messages for this chat if not cached
        if (!ms.isChatCached(chatId)) {
          await ms.loadMessages(chatId);
        }

        // Check if message already exists locally
        if (ms.hasMessage(chatId, messageId)) continue;

        // Add message from cloud
        final koraMsg = KoraMessage(
          id: messageId,
          text: msg['text'] as String? ?? '',
          timestamp: DateTime.tryParse(msg['timestamp'] as String? ?? '') ?? DateTime.now(),
          isMe: (msg['isMe'] as bool?) ?? false,
          type: _parseType(msg['type'] as String?),
          status: _parseStatus(msg['status'] as String?),
          replyToId: msg['replyToId'] as String?,
          replyToText: msg['replyToText'] as String?,
          replyToName: msg['replyToName'] as String?,
          reaction: msg['reaction'] as String?,
          voiceDuration: msg['voiceDuration'] as String?,
          voiceFilePath: msg['voiceFilePath'] as String?,
          voiceFileUrl: msg['voiceFileUrl'] as String?,
          isVoicePlayed: (msg['isVoicePlayed'] as bool?) ?? false,
          voiceTranscript: msg['voiceTranscript'] as String?,
          translatedLanguageCode: msg['translatedLanguageCode'] as String?,
          translatedLanguageName: msg['translatedLanguageName'] as String?,
          isAi: (msg['isAi'] as bool?) ?? false,
          isWebSearch: (msg['isWebSearch'] as bool?) ?? false,
          isSeen: (msg['isSeen'] as bool?) ?? true,
          isStarred: (msg['isStarred'] as bool?) ?? false,
          actionLabel: msg['actionLabel'] as String?,
          actionType: msg['actionType'] as String?,
        );

        await ms.addRestoredMessage(chatId, koraMsg);
        msgCount++;
      }

      lastPollTime = restoreTime;
    } catch (_) {
      // Best-effort — if cloud restore fails, local data is still intact.
    }

    _syncing = false;
    _restoring = false;
    return (conversations: convCount, messages: msgCount);
  }

  /// Fetch a full backup of all chat data (for the Chat Backup screen).
  Future<Map<String, dynamic>?> fetchBackup() async {
    if (_userEmail == null) return null;

    try {
      final response = await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'backup',
          'userEmail': _userEmail,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear all messages for a chat on the backend.
  Future<void> clearChatOnCloud(String chatId) async {
    if (_userEmail == null) return;

    try {
      await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'clearChat',
          'userEmail': _userEmail,
          'chatId': chatId,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort.
    }
  }

  Map<String, dynamic> _messageToJson(String chatId, KoraMessage msg) {
    return {
      'chatId': chatId,
      'messageId': msg.id,
      'text': msg.text,
      'timestamp': msg.timestamp.toIso8601String(),
      'isMe': msg.isMe,
      'type': msg.type.name,
      'status': msg.status.name,
      'replyToId': msg.replyToId,
      'replyToText': msg.replyToText,
      'replyToName': msg.replyToName,
      'reaction': msg.reaction,
      'voiceDuration': msg.voiceDuration,
      'voiceFilePath': msg.voiceFilePath,
      'voiceTranscript': msg.voiceTranscript,
      'translatedLanguageCode': msg.translatedLanguageCode,
      'translatedLanguageName': msg.translatedLanguageName,
      'isAi': msg.isAi,
      'isWebSearch': msg.isWebSearch,
      'isSeen': msg.isSeen,
      'isStarred': msg.isStarred,
      'actionLabel': msg.actionLabel,
      'actionType': msg.actionType,
    };
  }

  KoraMessageType _parseType(String? name) {
    return KoraMessageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => KoraMessageType.text,
    );
  }

  MessageStatus _parseStatus(String? name) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MessageStatus.none,
    );
  }
}
