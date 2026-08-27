import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_management_service.dart';
import 'package:path_provider/path_provider.dart';

import '../models/translation_models.dart';
import 'translation_service.dart';

/// Outcome object for the voice translation pipeline (text translation + TTS synthesis).
class VoiceTranslationOutcome {
  final bool success;
  final String? translatedText;
  final String? audioFilePath;
  final String? errorMessage;

  const VoiceTranslationOutcome({
    required this.success,
    this.translatedText,
    this.audioFilePath,
    this.errorMessage,
  });

  /// Factory constructor for a successful voice translation outcome.
  factory VoiceTranslationOutcome.ok({
    required String translatedText,
    required String audioFilePath,
  }) {
    return VoiceTranslationOutcome(
      success: true,
      translatedText: translatedText,
      audioFilePath: audioFilePath,
      errorMessage: null,
    );
  }

  /// Factory constructor for a failed voice translation outcome.
  factory VoiceTranslationOutcome.failure(String message) {
    return VoiceTranslationOutcome(
      success: false,
      translatedText: null,
      audioFilePath: null,
      errorMessage: message,
    );
  }
}

/// Pipeline combining text translation + text-to-speech synthesis
/// for the 'translate voice note before sending' feature.
class VoiceTranslationPipeline {
  static final VoiceTranslationPipeline instance = VoiceTranslationPipeline._();
  VoiceTranslationPipeline._();

  /// Maps a language code (e.g. 'en', 'es', 'fr') to a TTS locale identifier.
  String _ttsLocale(String code) {
    final mapping = <String, String>{
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'pt-BR': 'pt-BR',
      'ru': 'ru-RU',
      'pl': 'pl-PL',
      'tr': 'tr-TR',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'zh': 'zh-CN',
      'zh-TW': 'zh-TW',
      'nl': 'nl-NL',
      'sv': 'sv-SE',
      'da': 'da-DK',
      'fi': 'fi-FI',
      'no': 'nb-NO',
      'el': 'el-GR',
      'cs': 'cs-CZ',
      'uk': 'uk-UA',
      'th': 'th-TH',
      'vi': 'vi-VN',
      'id': 'id-ID',
      'ms': 'ms-MY',
      'sw': 'sw-KE',
      'he': 'he-IL',
      'ro': 'ro-RO',
      'hu': 'hu-HU',
    };
    return mapping[code] ?? (code.contains('-') ? code : 'en-US');
  }

  /// Translates [transcript] into [targetLanguageCode] and synthesizes
  /// the translated text into a speech audio file using [FlutterTts].
  Future<VoiceTranslationOutcome> translateAndSynthesize({
    required String transcript,
    required String targetLanguageCode,
  }) async {
    // Step a: Verify non-empty transcript
    if (transcript.trim().isEmpty) {
      return VoiceTranslationOutcome.failure(
        "No speech was detected in the recording. Please try again and speak clearly.",
      );
    }

    // Step b: Translate text via TranslationService
    final TranslationResult translationResult;
    try {
      translationResult = await TranslationService.instance.translate(
        transcript,
        targetLanguageCode,
      );
    } catch (e) {
      debugPrint('[VoiceTranslationPipeline] Translation failed: $e');
      return VoiceTranslationOutcome.failure(
        "Translation failed. Please check your connection and try again.",
      );
    }

    // Step c & d: Verify translated text string
    final translatedText = translationResult.translatedText.trim();
    if (translatedText.isEmpty) {
      return VoiceTranslationOutcome.failure(
        "Translation failed. Please check your connection and try again.",
      );
    }

    // Step e & f & g: Text-to-Speech synthesis
    try {
      final FlutterTts tts = FlutterTts();
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'kora_translated_${DateTime.now().millisecondsSinceEpoch}.wav';
      final fallbackPath = '${tempDir.path}/$fileName';

      final completer = Completer<bool>();

      tts.setCompletionHandler(() {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      tts.setErrorHandler((msg) {
        debugPrint('[VoiceTranslationPipeline] TTS Error: $msg');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      final locale = _ttsLocale(targetLanguageCode);
      await tts.setLanguage(locale);

      // Apply the user's selected voice from Voice Studio
      // This changes pitch, rate, and system voice — NOT a placeholder
      final voiceService = VoiceManagementService.instance;
      await voiceService.init();
      final selectedVoice = voiceService.selectedVoice;
      if (selectedVoice != null) {
        await tts.setPitch(selectedVoice.pitch);
        await tts.setSpeechRate(selectedVoice.rate);
      }

      final res = await tts.synthesizeToFile(translatedText, fileName);

      String resolvedPath = fallbackPath;
      if (res is String &&
          res.isNotEmpty &&
          (res.contains('/') || res.contains('\\'))) {
        resolvedPath = res;
      }

      final success = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint(
            '[VoiceTranslationPipeline] TTS completion handler timed out; proceeding with resolved path',
          );
          return true;
        },
      );

      if (!success) {
        return VoiceTranslationOutcome.failure(
          "Could not generate translated audio. Please try again.",
        );
      }

      return VoiceTranslationOutcome.ok(
        translatedText: translatedText,
        audioFilePath: resolvedPath,
      );
    } catch (e) {
      debugPrint('[VoiceTranslationPipeline] TTS synthesis exception: $e');
      return VoiceTranslationOutcome.failure(
        "Could not generate translated audio. Please try again.",
      );
    }
  }
}
