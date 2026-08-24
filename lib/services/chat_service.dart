import '../models/chat_models.dart';
import '../models/message_model.dart';
import 'message_service.dart';
import 'conversation_directory.dart';

/// Builds the Home chat list from real persisted conversations.
///
/// Kora Support and Kora AI appear in the chat list (not pinned) — they're
/// the built-in AI assistants. Every chat's pinned/muted/archived state
/// lives in [ConversationDirectoryService] and is preserved across app
/// runs. All other chats are built from the messages stored by
/// [MessageService] and the display metadata registered in
/// [ConversationDirectoryService] when a chat screen opens.
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  static const Map<String, String> _builtinAiChats = {
    'kora_support': 'Kora Support',
    'kora_ai': 'Kora AI',
  };

  static const Map<String, String> _builtinAiAvatars = {
    'kora_support': 'assets/images/kora_ai_avatar.png',
    'kora_ai': 'assets/images/kora_support_avatar.png',
  };

  static const Map<String, String> _builtinAiPlaceholders = {
    'kora_support': 'Welcome to Kora Messenger!',
    'kora_ai': 'Ask me anything — inside or outside Kora.',
  };

  /// Makes sure Kora Support and Kora AI always have a directory entry
  /// so their pin/mute/archive state persists exactly like any other
  /// chat instead of resetting on every app run.
  Future<void> _ensureBuiltinChatsRegistered() async {
    for (final chatId in _builtinAiChats.keys) {
      final existing = await ConversationDirectoryService.instance.get(chatId);
      if (existing == null) {
        await ConversationDirectoryService.instance.upsert(
          chatId: chatId,
          name: _builtinAiChats[chatId]!,
          avatarAsset: _builtinAiAvatars[chatId],
          badge: KoraBadgeType.officialPurple,
        );
      }
    }
  }

  /// Returns the current chat list, sorted: pinned chats first, then
  /// everything else by most recent message timestamp. Archived chats
  /// are excluded — see [getArchivedChats].
  Future<List<ChatPreview>> getChats() async {
    return _buildChats(archived: false);
  }

  /// Returns chats the user has archived, most recent first.
  Future<List<ChatPreview>> getArchivedChats() async {
    return _buildChats(archived: true);
  }

  Future<List<ChatPreview>> _buildChats({required bool archived}) async {
    await _ensureBuiltinChatsRegistered();

    final ms = MessageService.instance;
    final chats = <ChatPreview>[];
    final directory = await ConversationDirectoryService.instance.getAll();

    for (final entry in directory.entries) {
      final chatId = entry.key;
      final meta = entry.value;
      final isArchived = meta['isArchived'] as bool? ?? false;
      if (isArchived != archived) continue;

      final isBuiltinAi = _builtinAiChats.containsKey(chatId);

      final msgs = await ms.loadMessages(chatId);
      if (msgs.isEmpty && !isBuiltinAi) continue; // no messages yet — don't show empty row

      final last = msgs.isNotEmpty ? msgs.last : null;
      final isVoice = last?.type == KoraMessageType.voice;

      final String lastMessageText;
      final DateTime timestamp;
      if (last != null) {
        lastMessageText = isVoice
            ? 'Voice message${last.voiceDuration != null ? ' (${last.voiceDuration})' : ''}'
            : last.text;
        timestamp = last.timestamp;
      } else {
        lastMessageText = _builtinAiPlaceholders[chatId] ?? '';
        timestamp = DateTime.now();
      }

      chats.add(ChatPreview(
        id: chatId,
        name: meta['name'] as String? ?? chatId,
        avatarAsset: meta['avatarAsset'] as String?,
        avatarUrl: meta['avatarUrl'] as String?,
        lastMessage: lastMessageText,
        timestamp: timestamp,
        unreadCount: ms.unreadCountFor(chatId),
        badge: KoraBadgeType.values[meta['badge'] as int? ?? 0],
        isOnline: meta['isOnline'] as bool? ?? false,
        isPinned: meta['isPinned'] as bool? ?? false,
        isMuted: meta['isMuted'] as bool? ?? false,
        status: last != null && last.isMe ? last.status : MessageStatus.none,
        isVoiceLastMessage: isVoice,
        lastVoiceDuration: last?.voiceDuration,
      ));
    }

    chats.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    return chats;
  }
}
