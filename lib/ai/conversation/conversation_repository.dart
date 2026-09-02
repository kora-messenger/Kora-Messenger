import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation.dart';
import 'conversation_message.dart';

/// Local persistence for AI conversations using SharedPreferences.
class ConversationRepository {
  static const _convKey = 'kora_ai_conversations';
  static const _msgPrefix = 'kora_ai_msgs_';

  Future<Conversation> createConversation(String? title) async {
    final prefs = await SharedPreferences.getInstance();
    final conv = Conversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final list = _getConvList(prefs);
    list.add(conv.toJson());
    await prefs.setString(_convKey, jsonEncode(list));
    return conv;
  }

  Future<List<Conversation>> getConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _getConvList(prefs);
    return list.map((j) => Conversation.fromJson(j)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<Conversation?> getConversation(String id) async {
    final convs = await getConversations();
    for (final c in convs) { if (c.id == id) return c; }
    return null;
  }

  Future<void> updateConversation(Conversation conv) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _getConvList(prefs);
    final idx = list.indexWhere((c) => c['id'] == conv.id);
    if (idx >= 0) { list[idx] = conv.toJson(); await prefs.setString(_convKey, jsonEncode(list)); }
  }

  Future<void> deleteConversation(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _getConvList(prefs);
    list.removeWhere((c) => c['id'] == id);
    await prefs.setString(_convKey, jsonEncode(list));
    await prefs.remove('$_msgPrefix$id');
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final convs = await getConversations();
    final conv = convs.where((c) => c.id == id).firstOrNull;
    if (conv != null) await updateConversation(conv.copyWith(title: newTitle));
  }

  Future<void> addMessage(String conversationId, ConversationMessage msg) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_msgPrefix$conversationId';
    final list = _getMsgList(prefs, key);
    list.add(msg.toJson());
    await prefs.setString(key, jsonEncode(list));
    final convs = await getConversations();
    final conv = convs.where((c) => c.id == conversationId).firstOrNull;
    if (conv != null) {
      await updateConversation(conv.copyWith(
        updatedAt: DateTime.now(),
        messageCount: conv.messageCount + 1,
        lastMessagePreview: msg.content.length > 50 ? '${msg.content.substring(0, 50)}…' : msg.content,
      ));
    }
  }

  Future<List<ConversationMessage>> getMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_msgPrefix$conversationId';
    final list = _getMsgList(prefs, key);
    return list.map((j) => ConversationMessage.fromJson(j)).toList();
  }

  Future<void> clearMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_msgPrefix$conversationId');
  }

  List<Map<String, dynamic>> _getConvList(SharedPreferences prefs) {
    final raw = prefs.getString(_convKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _getMsgList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { return []; }
  }
}
