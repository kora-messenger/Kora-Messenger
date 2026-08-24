import '../models/chat_models.dart';
import '../models/message_model.dart';
import 'message_service.dart';
import 'conversation_directory.dart';

/// Builds the Home chat list from real persisted conversations.
///
/// All chats are built from the messages stored by [MessageService]
/// and the display metadata registered in [ConversationDirectoryService]
/// when a chat screen opens.
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  /// Returns the current chat list sorted by most recent message timestamp.
  Future<List<ChatPreview>> getChats() async {
    final ms = MessageService.instance;
    final chats = <ChatPreview>[];

    // Build real 1:1 / group chats from the conversation directory.
    // Each entry has a chatId — we load its messages from MessageService
    // to build the preview (last message, timestamp, unread, status).
    final directory = await ConversationDirectoryService.instance.getAll();
    for (final entry in directory.entries) {
      final chatId = entry.key;
      final meta = entry.value;

      // Ensure messages are loaded for this chat.
      final msgs = await ms.loadMessages(chatId);
      if (msgs.isEmpty) continue; // no messages yet — don't show empty row

      final last = msgs.last;
      final isVoice = last.type == KoraMessageType.voice;

      chats.add(ChatPreview(
        id: chatId,
        name: meta['name'] as String? ?? chatId,
        avatarAsset: meta['avatarAsset'] as String?,
        avatarUrl: meta['avatarUrl'] as String?,
        lastMessage: isVoice
            ? 'Voice message${last.voiceDuration != null ? ' (${last.voiceDuration})' : ''}'
            : last.text,
        timestamp: last.timestamp,
        unreadCount: ms.unreadCountFor(chatId),
        badge: KoraBadgeType.values[meta['badge'] as int? ?? 0],
        isOnline: meta['isOnline'] as bool? ?? false,
        isPinned: false,
        status: last.isMe ? last.status : MessageStatus.none,
        isVoiceLastMessage: isVoice,
        lastVoiceDuration: last.voiceDuration,
      ));
    }

    chats.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    return chats;
  }
}
