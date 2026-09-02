import 'dart:async';
import 'conversation/conversation.dart';
import 'conversation/conversation_message.dart';
import 'conversation/conversation_manager.dart';
import 'streaming/ai_stream_client.dart';
import 'streaming/ai_stream_event.dart';
import 'context/context_manager.dart';
import 'model/ai_request.dart';
/// Central AI coordinator for Kora Messenger.
/// Flow: UI → KoraAIManager → AIStreamClient → Kora AI API → AI Provider
class KoraAIManager {
  final ConversationManager conversationManager;
  final AIStreamClient streamClient;
  final ContextManager contextManager;

  KoraAIManager({
    required this.conversationManager,
    required this.streamClient,
    required this.contextManager,
  });

  Stream<AIStreamEvent> sendMessage({
    required String conversationId,
    required String message,
    List<AIAttachment>? attachments,
  }) async* {
    try {
      final history = await conversationManager.getHistory(conversationId);
      final contextList = contextManager.buildContext(
        messages: history,
        currentMessage: message,
        maxMessages: 10,
      );
      final request = AIRequest(
        conversationId: conversationId,
        message: message,
        history: contextList,
        attachments: attachments,
        feature: 'conversation',
        stream: true,
      );
      yield* streamClient.streamMessage(request);
    } catch (e) {
      yield AIStreamError(e.toString(), isRetryable: true);
    }
  }

  Future<Conversation> createConversation({String? title}) =>
      conversationManager.createConversation(title: title);
  Future<List<ConversationMessage>> getHistory(String conversationId) =>
      conversationManager.getHistory(conversationId);
  Future<void> cancelGeneration() => streamClient.cancel();
  Future<void> deleteConversation(String id) => conversationManager.deleteConversation(id);
  Future<void> renameConversation(String id, String title) => conversationManager.renameConversation(id, title);
  Future<List<Conversation>> listConversations() => conversationManager.listConversations();
}
