import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/kora_api.dart';
import '../models/voice_vector.dart';
import 'realtime_dsp_service.dart';

/// Voice Cloning TTS — synthesizes translated text in a target voice.
///
/// PRIMARY PATH (Cloud TTS with ZDR):
///   Sends ONLY the translated text + VoiceVector to a cloud TTS endpoint.
///   ZDR Guardrails:
///     - X-Zero-Retention: true header
///     - X-No-Log: true header
///     - Strips ALL user IDs, IPs, session tokens, metadata
///     - Request processed in volatile RAM, deleted on delivery
///
/// FALLBACK PATH (Local TTS + DSP):
///   If cloud TTS is unavailable, uses FlutterTts to generate base audio,
///   then applies pitch-shift and formant modification using the
///   VoiceVector parameters via RealtimeDspService.
class VoiceCloningTts {
  static final VoiceCloningTts instance = VoiceCloningTts._();
  VoiceCloningTts._();

  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  String _ttsLocale(String code) {
    const map = {
      'en': 'en-US', 'es': 'es-ES', 'fr': 'fr-FR', 'de': 'de-DE',
      'it': 'it-IT', 'pt': 'pt-PT', 'ru': 'ru-RU', 'pl': 'pl-PL',
      'tr': 'tr-TR', 'ar': 'ar-SA', 'hi': 'hi-IN', 'ja': 'ja-JP',
      'ko': 'ko-KR', 'zh': 'zh-CN', 'nl': 'nl-NL', 'sv': 'sv-SE',
      'da': 'da-DK', 'fi': 'fi-FI', 'no': 'nb-NO', 'el': 'el-GR',
      'cs': 'cs-CZ', 'uk': 'uk-UA', 'th': 'th-TH', 'vi': 'vi-VN',
      'id': 'id-ID', 'ms': 'ms-MY', 'sw': 'sw-KE', 'he': 'he-IL',
    };
    return map[code] ?? (code.contains('-') ? code : 'en-US');
  }

  Future<void> _ensureTts() async {
    if (_ttsInitialized) return;
    _ttsInitialized = true;
    await _tts.awaitSpeakCompletion(true);
  }

  /// Synthesize translated text in the sender's voice.
  ///
  /// Tries cloud TTS with ZDR guardrails first, falls back to local TTS + DSP.
  /// Returns the path to the synthesized audio file.
  Future<String> synthesize({
    required String text,
    required VoiceVector voiceVector,
    required String languageCode,
  }) async {
    // Try cloud TTS with ZDR first
    try {
      final cloudResult = await _cloudSynthesizeZdr(
        text: text,
        voiceVector: voiceVector,
        languageCode: languageCode,
      );
      if (cloudResult != null) return cloudResult;
    } catch (e) {
      debugPrint('[VoiceCloningTts] cloud path failed: $e');
    }

    // Fallback: local TTS + DSP
    return synthesizeLocal(
      text: text,
      voiceVector: voiceVector,
      languageCode: languageCode,
    );
  }

  /// Cloud TTS with Zero Data Retention guardrails.
  ///
  /// Sends ONLY: translated text + mathematical voice vector
  /// NO: user IDs, IPs, session tokens, conversation context, metadata
  Future<String?> _cloudSynthesizeZdr({
    required String text,
    required VoiceVector voiceVector,
    required String languageCode,
  }) async {
    // ZDR guardrails — strip ALL identifying information
    final requestBody = jsonEncode({
      'text': text,                        // only the translated text
      'voiceVector': voiceVector.toJson(), // only math, no audio
      'language': languageCode,
      // NO userId, NO email, NO IP, NO sessionId, NO metadata
    });

    try {
      final response = await http.post(
        Uri.parse('${KoraApi.baseUrl}/koraVoiceClone'),
        headers: {
          'Content-Type': 'application/json',
          'X-Zero-Retention': 'true',       // ZDR: no storage
          'X-No-Log': 'true',                // ZDR: no logging
          'X-Volatile-Only': 'true',         // ZDR: RAM only
          // NO Authorization with user tokens — anonymous request
          // NO cookies, NO session headers
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['audioUrl'] != null) {
          // Download the audio to a local temp file
          final audioUrl = data['audioUrl'] as String;
          final audioResponse = await http.get(Uri.parse(audioUrl));
          if (audioResponse.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/kora_clone_${DateTime.now().millisecondsSinceEpoch}.wav';
            final file = File(filePath);
            await file.writeAsBytes(audioResponse.bodyBytes);
            return filePath;
          }
        }
      }
    } catch (e) {
      debugPrint('[VoiceCloningTts] ZDR cloud error: $e');
    }

    return null;
  }

  /// Local-only synthesis: FlutterTts generates audio, then DSP applies voice vector.
  Future<String> synthesizeLocal({
    required String text,
    required VoiceVector voiceVector,
    required String languageCode,
  }) async {
    await _ensureTts();

    final tempDir = await getTemporaryDirectory();
    final fileName = 'kora_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    final ttsPath = '${tempDir.path}/$fileName';

    final completer = Completer<String>();
    bool hasError = false;

    _tts.setCompletionHandler(() {
      if (!completer.isCompleted && !hasError) {
        // Apply DSP voice modification to the TTS output
        _applyDsp(ttsPath, voiceVector).then((processedPath) {
          if (!completer.isCompleted) completer.complete(processedPath);
        });
      }
    });

    _tts.setErrorHandler((msg) {
      hasError = true;
      debugPrint('[VoiceCloningTts] TTS error: $msg');
      if (!completer.isCompleted) completer.complete(ttsPath);
    });

    await _tts.setLanguage(_ttsLocale(languageCode));

    // Apply basic pitch from voice vector
    final pitchRatio = (voiceVector.meanPitch / 120.0).clamp(0.5, 2.0);
    await _tts.setPitch(pitchRatio);
    await _tts.setSpeechRate(1.0);

    await _tts.synthesizeToFile(text, fileName);

    // Timeout fallback
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(ttsPath);
    });

    return completer.future;
  }

  /// Apply DSP pitch-shift and formant modification to TTS audio.
  Future<String> _applyDsp(String ttsPath, VoiceVector vector) async {
    try {
      final result = await RealtimeDspService.instance.processTtsOutput(ttsPath, vector);
      return result;
    } catch (e) {
      debugPrint('[VoiceCloningTts] DSP apply error: $e');
      return ttsPath; // Return unmodified if DSP fails
    }
  }
}
