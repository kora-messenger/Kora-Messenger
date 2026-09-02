import '../conversation/conversation_message.dart';

/// Manages context window for AI requests.
/// Optimizes which messages to send: recent N + summarized older ones.
class ContextManager {
  List<Map<String, dynamic>> buildContext({
    required List<ConversationMessage> messages,
    required String currentMessage,
    String? systemPrompt,
    int maxMessages = 10,
    int maxTokens = 4000,
  }) {
    final context = <Map<String, dynamic>>[];
    if (systemPrompt != null) context.add({'role': 'system', 'content': systemPrompt});

    if (messages.length <= maxMessages) {
      for (final msg in messages) {
        context.add({'role': msg.role == MessageRole.user ? 'user' : 'assistant', 'content': msg.content});
      }
    } else {
      final olderCount = messages.length - maxMessages;
      context.add({'role': 'system', 'content': '[Earlier context — $olderCount older messages omitted]'});
      final recent = messages.sublist(messages.length - maxMessages);
      for (final msg in recent) {
        context.add({'role': msg.role == MessageRole.user ? 'user' : 'assistant', 'content': msg.content});
      }
    }
    context.add({'role': 'user', 'content': currentMessage});
    return context;
  }

  String summarizeOlderMessages(List<ConversationMessage> oldMessages) {
    if (oldMessages.isEmpty) return '';
    final userCount = oldMessages.where((m) => m.role == MessageRole.user).length;
    final aiCount = oldMessages.where((m) => m.role == MessageRole.assistant).length;
    final firstMsg = oldMessages.first.content;
    return 'Previous conversation with $userCount user messages and $aiCount AI responses. '
        'Started with: "${firstMsg.length > 50 ? '${firstMsg.substring(0, 50)}…' : firstMsg}".';
  }
}
