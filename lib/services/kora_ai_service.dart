import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/kora_api.dart';

/// Message model for AI conversations.
class KoraAiMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  KoraAiMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory KoraAiMessage.fromJson(Map<String, dynamic> json) => KoraAiMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  /// Convert to the format expected by the server's clean_history()
  Map<String, dynamic> toHistoryJson() => {
        'role': role,
        'content': content,
      };
}

/// Result of an AI request.
class KoraAiResult {
  final bool success;
  final String response;
  final String? error;

  KoraAiResult({
    required this.success,
    required this.response,
    this.error,
  });
}

/// Central AI service for Kora Messenger.
///
/// Handles:
/// - Sending messages to Kora AI and Kora AI Support
/// - Conversation history (persisted locally)
/// - Image attachment support (Kora AI only)
///
/// All API calls go through [KoraApi] — domain-swappable.
/// The OpenRouter key stays server-side; the app never sees it.
class KoraAiService {
  static final KoraAiService instance = KoraAiService._();
  KoraAiService._();

  static const String _kAiHistoryPrefix = 'kora_ai_history_';
  static const String _kSupportHistoryPrefix = 'kora_support_history_';

  /// Send a message to Kora AI (general assistant).
  ///
  /// [conversationId] should be unique per conversation.
  /// [imageBase64] optional base64-encoded image for vision support.
  /// [webUrl] optional URL for web research.
  Future<KoraAiResult> sendAiMessage({
    required String message,
    required String conversationId,
    String? imageBase64,
    String? webUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'message': message,
        'conversationId': conversationId,
      };

      if (imageBase64 != null) body['imageBase64'] = imageBase64;
      if (webUrl != null) body['webUrl'] = webUrl;

      final result = await KoraApi.postToAi(KoraApi.aiChatEndpoint, body);

      if (result.containsKey('error')) {
        return KoraAiResult(
          success: false,
          response: '',
          error: result['error'] as String,
        );
      }

      final response = result['response'] as String? ?? '';

      // Save to local history
      await _saveToHistory(
        prefix: _kAiHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'user', content: message),
      );
      await _saveToHistory(
        prefix: _kAiHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'assistant', content: response),
      );

      return KoraAiResult(success: true, response: response);
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Connection failed: $e',
      );
    }
  }

  /// Send a message to Kora AI Support (product support).
  Future<KoraAiResult> sendSupportMessage({
    required String message,
    required String conversationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'message': message,
        'conversationId': conversationId,
      };

      final result = await KoraApi.postToAi(KoraApi.aiSupportEndpoint, body);

      if (result.containsKey('error')) {
        return KoraAiResult(
          success: false,
          response: '',
          error: result['error'] as String,
        );
      }

      final response = result['response'] as String? ?? '';

      // Save to local history
      await _saveToHistory(
        prefix: _kSupportHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'user', content: message),
      );
      await _saveToHistory(
        prefix: _kSupportHistoryPrefix,
        conversationId: conversationId,
        message: KoraAiMessage(role: 'assistant', content: response),
      );

      return KoraAiResult(success: true, response: response);
    } catch (e) {
      return KoraAiResult(
        success: false,
        response: '',
        error: 'Connection failed: $e',
      );
    }
  }

  /// Get conversation history for a given conversation.
  Future<List<KoraAiMessage>> getHistory({
    required String conversationId,
    bool isSupport = false,
  }) async {
    final prefix = isSupport ? _kSupportHistoryPrefix : _kAiHistoryPrefix;
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefix$conversationId';
    final json = prefs.getString(key);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => KoraAiMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear conversation history.
  Future<void> clearConversation({
    required String conversationId,
    bool isSupport = false,
  }) async {
    final prefix = isSupport ? _kSupportHistoryPrefix : _kAiHistoryPrefix;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$prefix$conversationId');
  }

  /// Save a message to local history.
  Future<void> _saveToHistory({
    required String prefix,
    required String conversationId,
    required KoraAiMessage message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefix$conversationId';
    final json = prefs.getString(key);

    List<KoraAiMessage> history = [];
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        history = list
            .map((e) => KoraAiMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    history.add(message);

    // Keep only last 50 messages locally
    if (history.length > 50) {
      history = history.sublist(history.length - 50);
    }

    await prefs.setString(
      key,
      jsonEncode(history.map((m) => m.toJson()).toList()),
    );
  }

  /// Generate a unique conversation ID.
  String generateConversationId({bool isSupport = false}) {
    final prefix = isSupport ? 'support' : 'ai';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp';
  }
}
