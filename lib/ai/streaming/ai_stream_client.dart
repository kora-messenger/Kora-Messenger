import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../config/kora_api.dart';
import '../model/ai_request.dart';
import 'ai_stream_event.dart';

/// Streaming client for AI responses using SSE (Server-Sent Events).
/// Connects to the Kora AI Orchestrator backend and parses SSE format.
class AIStreamClient {
  http.Client? _client;
  bool _isCancelled = false;

  Stream<AIStreamEvent> streamMessage(AIRequest request) async* {
    _isCancelled = false;
    _client = http.Client();
    yield AIStreamStarted();

    try {
      final body = request.toJson();
      body['stream'] = true;

      final response = await _client!.post(
        Uri.parse(KoraApi.aiOrchestratorEndpoint),
        headers: {'Content-Type': 'application/json', 'Accept': 'text/event-stream'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        yield AIStreamError('Server error: ${response.statusCode}', isRetryable: response.statusCode >= 500);
        return;
      }

      final lines = response.body.split('\n');
      final fullText = StringBuffer();

      for (final line in lines) {
        if (_isCancelled) { yield AIStreamStopped(); return; }
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6);
        if (data == '[DONE]') continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (json['error'] != null) {
            yield AIStreamError(json['error'] as String, isRetryable: true);
            return;
          }
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              fullText.write(content);
              yield AIStreamTextDelta(content);
            }
          }
        } catch (_) {}
      }

      if (!_isCancelled && fullText.isNotEmpty) {
        yield AIStreamMessageCompleted('msg_${DateTime.now().millisecondsSinceEpoch}', fullText.toString());
      }
    } catch (e) {
      if (!_isCancelled) {
        yield AIStreamError(e is http.ClientException ? 'Network error' : e.toString(), isRetryable: true);
      }
    } finally {
      _client?.close();
      _client = null;
    }
  }

  Future<void> cancel() async {
    _isCancelled = true;
    _client?.close();
    _client = null;
  }
}
