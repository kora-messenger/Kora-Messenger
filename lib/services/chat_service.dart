import '../models/chat_models.dart';

/// Mock chat data for the Home Screen.
/// Replace with real backend calls once messaging is wired up.
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  /// Toggle this to preview the empty state during development.
  bool showEmptyState = false;

  List<ChatPreview> getChats() {
    if (showEmptyState) return [];

    final now = DateTime.now();

    return [
      ChatPreview(
        id: 'kora_support',
        name: 'Kora Support',
        avatarAsset: 'assets/images/kora_support_avatar.png',
        lastMessage: 'Welcome to Kora! Let us know if you need any help getting started.',
        timestamp: now.subtract(const Duration(minutes: 4)),
        unreadCount: 1,
        badge: KoraBadgeType.officialPurple,
        isPinned: true,
        status: MessageStatus.none,
      ),
      ChatPreview(
        id: 'kora_ai',
        name: 'Kora AI Assistant',
        avatarAsset: 'assets/images/kora_ai_avatar.png',
        lastMessage: 'Ask me anything — I can help you plan, write, or organize.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 12)),
        unreadCount: 0,
        badge: KoraBadgeType.officialPurple,
        isPinned: true,
        status: MessageStatus.none,
      ),
      ChatPreview(
        id: 'c1',
        name: 'Amara Chukwu',
        lastMessage: 'Sounds great, see you then!',
        timestamp: now.subtract(const Duration(minutes: 18)),
        unreadCount: 3,
        badge: KoraBadgeType.premiumBlue,
        status: MessageStatus.delivered,
        isOnline: true,
      ),
      ChatPreview(
        id: 'c2',
        name: 'David Okoro',
        lastMessage: 'You: Sent the files, check your email',
        timestamp: now.subtract(const Duration(hours: 2)),
        status: MessageStatus.read,
        isMuted: true,
      ),
      ChatPreview(
        id: 'c3',
        name: 'Design Team',
        lastMessage: 'Chidi: Updated the mockups 🎨',
        timestamp: now.subtract(const Duration(hours: 5)),
        unreadCount: 12,
        status: MessageStatus.none,
      ),
      ChatPreview(
        id: 'c4',
        name: 'Grace Adeyemi',
        lastMessage: 'typing…',
        timestamp: now.subtract(const Duration(hours: 6)),
        status: MessageStatus.sent,
        isTyping: true,
        isOnline: true,
      ),
      ChatPreview(
        id: 'c5',
        name: 'Emeka Nwosu',
        lastMessage: 'You: 👍',
        timestamp: now.subtract(const Duration(days: 1)),
        status: MessageStatus.read,
      ),
      ChatPreview(
        id: 'c6',
        name: 'Family Group',
        lastMessage: 'Mum: Don\'t forget dinner on Sunday',
        timestamp: now.subtract(const Duration(days: 2)),
        unreadCount: 5,
      ),
    ]..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.timestamp.compareTo(a.timestamp);
      });
  }
}
