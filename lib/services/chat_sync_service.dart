import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kora_api.dart';
import '../models/message_model.dart';
import '../models/chat_models.dart';
import 'message_service.dart';
import 'conversation_directory.dart';

/// Syncs Kora chats and messages to/from the Base44 database.
///
/// On every message send/receive, [syncMessage] pushes it to the backend.
/// On login or app start, [restoreFromCloud] fetches all conversations and
/// messages from the database — so even if the user deletes and reinstalls
/// the app, logging in with the same email restores every chat.
class ChatSyncService {
  static final ChatSyncService instance = ChatSyncService._();
  ChatSyncService._();

  String? _userEmail;
  bool _syncing = false;

  /// Set the user's email — called after login.
  void setUserEmail(String email) {
    _userEmail = email;
  }

  String? get userEmail => _userEmail;

  /// Sync a single message to the backend (fire-and-forget).
  Future<void> syncMessage(String chatId, KoraMessage msg) async {
    if (_userEmail == null) return;
    if (_syncing) return; // don't sync during bulk restore

    try {
      await http.post(
        Uri.parse(KoraApi.chatSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'sync',
          'userEmail': _userEmail,
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
    int convCount = 0;
    int msgCount = 0;

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
    } catch (_) {
      // Best-effort — if cloud restore fails, local data is still intact.
    }

    _syncing = false;
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
