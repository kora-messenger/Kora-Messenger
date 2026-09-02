import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../config/kora_api.dart';
import '../model/ai_request.dart';
import '../model/ai_response.dart';
import '../streaming/ai_stream_event.dart';

/// Translation orchestration for text, voice notes, and group messages.
/// Uses the Kora AI Orchestrator backend with intent=translation.
class TranslationManager {
  final http.Client _client = http.Client();

  /// Translate text to a target language.
  Future<AIResponse> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(KoraApi.aiOrchestratorEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'intent': 'translation',
          'message': text,
          'targetLanguage': targetLanguage,
          'sourceLanguage': sourceLanguage,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return AIResponse.fromJson(jsonDecode(response.body));
      }
      return AIResponse(success: false, content: '', error: 'Server error: ${response.statusCode}');
    } catch (e) {
      return AIResponse(success: false, content: '', error: e.toString());
    }
  }

  /// Translate a voice note transcript.
  Future<AIResponse> translateVoiceNote({
    required String transcript,
    required String targetLanguage,
  }) async {
    return translateText(text: transcript, targetLanguage: targetLanguage);
  }

  /// Stream a realtime translation (for live calls or messaging).
  Stream<AIStreamEvent> translateRealtime({
    required String text,
    required String targetLanguage,
  }) async* {
    yield AIStreamStarted();
    try {
      final request = AIRequest(
        conversationId: 'translation_realtime',
        message: text,
        feature: 'translation',
        stream: true,
      );
      final body = request.toJson();
      body['targetLanguage'] = targetLanguage;

      final response = await _client.post(
        Uri.parse(KoraApi.aiOrchestratorEndpoint),
        headers: {'Content-Type': 'application/json', 'Accept': 'text/event-stream'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        yield AIStreamError('Translation failed: ${response.statusCode}', isRetryable: true);
        return;
      }

      final lines = response.body.split('\n');
      final fullText = StringBuffer();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6);
        if (data == '[DONE]') continue;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = (choices[0]['delta']?['content']) as String?;
            if (content != null && content.isNotEmpty) {
              fullText.write(content);
              yield AIStreamTextDelta(content);
            }
          }
        } catch (_) {}
      }
      if (fullText.isNotEmpty) {
        yield AIStreamMessageCompleted('trans_${DateTime.now().millisecondsSinceEpoch}', fullText.toString());
      }
    } catch (e) {
      yield AIStreamError(e.toString(), isRetryable: true);
    }
  }

  void dispose() { _client.close(); }
}
