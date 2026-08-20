import '../models/chat_models.dart';
import 'message_service.dart';

/// Builds the Home chat list from real persisted conversations.
///
/// Kora Support and Kora AI are always pinned at the top — they're
/// the built-in AI assistants. All other chats are built from the
/// messages stored by [MessageService].
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  /// Returns the current chat list, sorted: pinned official chats first,
  /// then everything else by most recent message timestamp.
  List<ChatPreview> getChats() {
    final ms = MessageService.instance;
    final chats = <ChatPreview>[];

    // Always show Kora Support (pinned, official purple badge)
    final supportMsgs = ms.getMessages('kora_support');
    chats.add(ChatPreview(
      id: 'kora_support',
      name: 'Kora Support',
      avatarAsset: 'assets/images/kora_support_avatar.png',
      lastMessage: supportMsgs.isNotEmpty
          ? supportMsgs.last.text
          : 'Welcome to Kora Messenger!',
      timestamp: supportMsgs.isNotEmpty
          ? supportMsgs.last.timestamp
          : DateTime.now(),
      unreadCount: ms.unreadCountFor('kora_support'),
      badge: KoraBadgeType.officialPurple,
      isPinned: true,
      status: MessageStatus.none,
    ));

    // Always show Kora AI (pinned, official purple badge)
    final aiMsgs = ms.getMessages('kora_ai');
    chats.add(ChatPreview(
      id: 'kora_ai',
      name: 'Kora AI',
      avatarAsset: 'assets/images/kora_ai_avatar.png',
      lastMessage: aiMsgs.isNotEmpty
          ? aiMsgs.last.text
          : 'Ask me anything — inside or outside Kora.',
      timestamp: aiMsgs.isNotEmpty
          ? aiMsgs.last.timestamp
          : DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: ms.unreadCountFor('kora_ai'),
      badge: KoraBadgeType.officialPurple,
      isPinned: true,
      status: MessageStatus.none,
    ));

    // Build chats from all persisted message keys
    // (loaded from SharedPreferences by MessageService.init on startup)
    // For now, only the two official chats are shown. When real
    // 1:1 / group messaging is wired up, this will iterate over
    // conversation IDs stored on the backend.

    chats.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    return chats;
  }
}
