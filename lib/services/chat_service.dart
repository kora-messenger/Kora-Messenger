import '../models/chat_models.dart';
import '../models/message_model.dart';
import 'message_service.dart';
import 'conversation_directory.dart';

/// Builds the Home chat list from real persisted conversations.
///
/// Kora Support and Kora AI are always pinned at the top — they're
/// the built-in AI assistants. All other chats are built from the
/// messages stored by [MessageService] and the display metadata
/// registered in [ConversationDirectoryService] when a chat screen
/// opens.
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  /// Returns the current chat list, sorted: pinned official chats first,
  /// then everything else by most recent message timestamp.
  Future<List<ChatPreview>> getChats() async {
    final ms = MessageService.instance;
    final chats = <ChatPreview>[];

    // Always show Kora Support (pinned, official purple badge)
    final supportMsgs = ms.getMessages('kora_support');
    chats.add(ChatPreview(
      id: 'kora_support',
      name: 'Kora Support',
      avatarAsset: 'assets/images/kora_ai_avatar.png',
      lastMessage: supportMsgs.isNotEmpty
          ? (supportMsgs.last.type == KoraMessageType.voice
              ? 'Voice message${supportMsgs.last.voiceDuration != null ? ' (${supportMsgs.last.voiceDuration})' : ''}'
              : supportMsgs.last.text)
          : 'Welcome to Kora Messenger!',
      timestamp: supportMsgs.isNotEmpty
          ? supportMsgs.last.timestamp
          : DateTime.now(),
      unreadCount: ms.unreadCountFor('kora_support'),
      badge: KoraBadgeType.officialPurple,
      isPinned: true,
      status: supportMsgs.isNotEmpty && supportMsgs.last.isMe
          ? supportMsgs.last.status
          : MessageStatus.none,
      isVoiceLastMessage: supportMsgs.isNotEmpty &&
          supportMsgs.last.type == KoraMessageType.voice,
      lastVoiceDuration: supportMsgs.isNotEmpty
          ? supportMsgs.last.voiceDuration
          : null,
    ));

    // Always show Kora AI (pinned, official purple badge)
    final aiMsgs = ms.getMessages('kora_ai');
    chats.add(ChatPreview(
      id: 'kora_ai',
      name: 'Kora AI',
      avatarAsset: 'assets/images/kora_support_avatar.png',
      lastMessage: aiMsgs.isNotEmpty
          ? (aiMsgs.last.type == KoraMessageType.voice
              ? 'Voice message${aiMsgs.last.voiceDuration != null ? ' (${aiMsgs.last.voiceDuration})' : ''}'
              : aiMsgs.last.text)
          : 'Ask me anything — inside or outside Kora.',
      timestamp: aiMsgs.isNotEmpty
          ? aiMsgs.last.timestamp
          : DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: ms.unreadCountFor('kora_ai'),
      badge: KoraBadgeType.officialPurple,
      isPinned: true,
      status: aiMsgs.isNotEmpty && aiMsgs.last.isMe
          ? aiMsgs.last.status
          : MessageStatus.none,
      isVoiceLastMessage: aiMsgs.isNotEmpty &&
          aiMsgs.last.type == KoraMessageType.voice,
      lastVoiceDuration: aiMsgs.isNotEmpty
          ? aiMsgs.last.voiceDuration
          : null,
    ));

    // Build real 1:1 / group chats from the conversation directory.
    // Each entry has a chatId — we load its messages from MessageService
    // to build the preview (last message, timestamp, unread, status).
    final directory = await ConversationDirectoryService.instance.getAll();
    for (final entry in directory.entries) {
      final chatId = entry.key;
      final meta = entry.value;

      // Skip the official chats — already handled above.
      if (chatId == 'kora_support' || chatId == 'kora_ai') continue;

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
