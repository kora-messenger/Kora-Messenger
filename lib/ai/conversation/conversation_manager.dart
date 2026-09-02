import 'conversation.dart';
import 'conversation_message.dart';
import 'conversation_repository.dart';

/// Manages AI conversations — create, list, delete, rename, add messages.
/// Auto-generates titles from the first user message.
class ConversationManager {
  final ConversationRepository _repo;
  ConversationManager(this._repo);

  Future<Conversation> createConversation({String? title}) => _repo.createConversation(title);
  Future<List<Conversation>> listConversations() => _repo.getConversations();
  Future<void> deleteConversation(String id) => _repo.deleteConversation(id);
  Future<void> renameConversation(String id, String title) => _repo.renameConversation(id, title);
  Future<List<ConversationMessage>> getHistory(String conversationId) => _repo.getMessages(conversationId);

  Future<void> addMessage(String conversationId, ConversationMessage msg) async {
    await _repo.addMessage(conversationId, msg);
    final conv = await _repo.getConversation(conversationId);
    if (conv != null && conv.title == null && msg.role == MessageRole.user) {
      final title = msg.content.length > 40 ? '${msg.content.substring(0, 40)}…' : msg.content;
      await _repo.renameConversation(conversationId, title);
    }
  }

  Future<void> clearMessages(String conversationId) => _repo.clearMessages(conversationId);
}
