import '../models/message_model.dart';
import '../models/chat_models.dart';

/// Mock message data per conversation.
/// Replace with real backend once messaging is wired up.
class MessageService {
  static final MessageService instance = MessageService._();
  MessageService._();

  final Map<String, List<KoraMessage>> _messages = {};

  /// Returns messages for a chat ID, seeding defaults if empty.
  List<KoraMessage> getMessages(String chatId) {
    if (_messages.containsKey(chatId)) return _messages[chatId]!;

    final now = DateTime.now();
    List<KoraMessage> seeded;

    switch (chatId) {
      case 'kora_support':
        seeded = [
          KoraMessage(
            id: 's1',
            text: 'Welcome to Kora Messenger! 👋',
            timestamp: now.subtract(const Duration(minutes: 30)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 's2',
            text: 'I\'m here to help with anything you need — setting up your profile, finding contacts, or troubleshooting.',
            timestamp: now.subtract(const Duration(minutes: 29)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 's3',
            text: 'Thanks! Excited to start using Kora.',
            timestamp: now.subtract(const Duration(minutes: 28)),
            isMe: true,
            status: MessageStatus.read,
          ),
          KoraMessage(
            id: 's4',
            text: 'That\'s great to hear! Let us know if you have any questions. You can also check the Help section in Settings.',
            timestamp: now.subtract(const Duration(minutes: 27)),
            isMe: false,
            status: MessageStatus.none,
          ),
        ];
        break;

      case 'kora_ai':
        seeded = [
          KoraMessage(
            id: 'a1',
            text: 'Hi! I\'m Kora AI — your built-in assistant. Ask me anything.',
            timestamp: now.subtract(const Duration(hours: 2)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 'a2',
            text: 'I can help you plan, write, translate, summarize, or just chat.',
            timestamp: now.subtract(const Duration(hours: 2)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 'a3',
            text: 'Can you translate "Good morning" to French?',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 50)),
            isMe: true,
            status: MessageStatus.read,
          ),
          KoraMessage(
            id: 'a4',
            text: 'Of course! "Good morning" in French is "Bonjour" 🌅',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 49)),
            isMe: false,
            status: MessageStatus.none,
          ),
        ];
        break;

      case 'c1': // Amara Chukwu
        seeded = [
          KoraMessage(
            id: 'm1',
            text: 'Hey! Are we still on for tomorrow?',
            timestamp: now.subtract(const Duration(minutes: 25)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 'm2',
            text: 'Yes, absolutely. Same time?',
            timestamp: now.subtract(const Duration(minutes: 22)),
            isMe: true,
            status: MessageStatus.read,
          ),
          KoraMessage(
            id: 'm3',
            text: 'Perfect. I\'ll send the location.',
            timestamp: now.subtract(const Duration(minutes: 20)),
            isMe: false,
            status: MessageStatus.none,
          ),
          KoraMessage(
            id: 'm4',
            text: 'Sounds great, see you then!',
            timestamp: now.subtract(const Duration(minutes: 18)),
            isMe: false,
            status: MessageStatus.none,
            reaction: '❤️',
          ),
        ];
        break;

      default:
        seeded = [];
    }

    _messages[chatId] = seeded;
    return seeded;
  }

  /// Send a new text message.
  void sendMessage(String chatId, String text, {String? replyToId, String? replyToText, String? replyToName}) {
    final messages = _messages.putIfAbsent(chatId, () => []);
    messages.add(KoraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToName: replyToName,
    ));
  }

  /// Send a voice message (mock).
  void sendVoiceMessage(String chatId, String duration) {
    final messages = _messages.putIfAbsent(chatId, () => []);
    messages.add(KoraMessage(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      timestamp: DateTime.now(),
      isMe: true,
      type: KoraMessageType.voice,
      status: MessageStatus.sent,
      voiceDuration: duration,
    ));
  }

  /// Add a reaction to a message.
  void toggleReaction(String chatId, String messageId, String emoji) {
    final messages = _messages[chatId];
    if (messages == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = messages[idx];
    messages[idx] = msg.copyWith(reaction: msg.reaction == emoji ? null : emoji);
  }

  /// Delete a message.
  void deleteMessage(String chatId, String messageId) {
    final messages = _messages[chatId];
    if (messages == null) return;
    messages.removeWhere((m) => m.id == messageId);
  }

  /// Mark all outgoing messages as read (mock — when the other person "reads").
  void markAsRead(String chatId) {
    final messages = _messages[chatId];
    if (messages == null) return;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].isMe && messages[i].status != MessageStatus.read) {
        messages[i] = messages[i].copyWith(status: MessageStatus.read);
      }
    }
  }
}
