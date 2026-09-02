import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../config/kora_api.dart';
import '../model/ai_response.dart';
import '../streaming/ai_stream_event.dart';

/// Voice AI manager — handles speech-to-text, text-to-speech, and voice conversations.
/// Keeps voice AI separate from the normal Kora voice-note system.
class AIVoiceManager {
  static const _platform = MethodChannel('com.kora.messenger/voice_ai');

  final http.Client _client = http.Client();
  bool _isSpeaking = false;
  bool _isListening = false;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;

  /// Transcribe audio to text using the backend AI orchestrator.
  Future<String> transcribeAudio(String audioPath) async {
    try {
      final response = await _client.post(
        Uri.parse(KoraApi.aiOrchestratorEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'intent': 'voice_transcribe',
          'message': audioPath,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] as String? ?? '';
      }
      return '';
    } catch (e) {
      debugPrint('[AIVoiceManager] Transcribe error: $e');
      return '';
    }
  }

  /// Stream a voice conversation (for realtime voice AI).
  Stream<AIStreamEvent> voiceConversation(Stream<List<int>> audioStream) async* {
    yield AIStreamStarted();
    // Realtime voice processing would use WebSocket/WebRTC
    // For now, collect audio and transcribe
    try {
      final chunks = <List<int>>[];
      await for (final chunk in audioStream) { chunks.add(chunk); }
      // Process collected audio
      final combined = chunks.expand((c) => c).toList();
      final transcript = await transcribeAudio(base64Encode(combined));
      if (transcript.isNotEmpty) {
        yield AIStreamTextDelta(transcript);
        yield AIStreamMessageCompleted('voice_${DateTime.now().millisecondsSinceEpoch}', transcript);
      }
    } catch (e) {
      yield AIStreamError(e.toString(), isRetryable: true);
    }
  }

  /// Speak text using platform TTS (text-to-speech).
  Future<void> speakText(String text, {String? language}) async {
    if (kIsWeb) {
      debugPrint('[AIVoiceManager] TTS not available on web');
      return;
    }
    try {
      _isSpeaking = true;
      await _platform.invokeMethod('speak', {'text': text, 'language': language ?? 'en'});
    } catch (e) {
      debugPrint('[AIVoiceManager] TTS error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stop any ongoing speech.
  Future<void> stopSpeaking() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('stopSpeaking');
    } catch (_) {}
    _isSpeaking = false;
  }

  /// Start listening for voice input (speech-to-text).
  Future<void> startListening() async {
    if (kIsWeb) return;
    try {
      _isListening = true;
      await _platform.invokeMethod('startListening');
    } catch (e) {
      debugPrint('[AIVoiceManager] Start listening error: $e');
      _isListening = false;
    }
  }

  /// Stop listening.
  Future<void> stopListening() async {
    if (kIsWeb) return;
    try { await _platform.invokeMethod('stopListening'); } catch (_) {}
    _isListening = false;
  }

  void dispose() {
    _client.close();
    stopSpeaking();
    stopListening();
  }
}
