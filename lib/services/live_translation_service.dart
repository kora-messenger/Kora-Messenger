import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/kora_api.dart';

/// Live voice-to-voice translation service for Kora calls.
///
/// Pipeline:
/// 1. STT captures the user's speech on-device
/// 2. Transcribed text is sent to koraTranslate backend
/// 3. Translated text is sent to the other person via WebRTC data channel
/// 4. The other person's device receives it and plays it via TTS
/// 5. Same happens in reverse
///
/// The TTS voice can be customized in the future with a voice profile
/// uploaded via Settings > Voice & Media. For now, uses on-device TTS
/// with the best available voice for the target language.
///
/// Architecture is domain-swappable — when a cloud TTS with voice
/// cloning is added, only this file changes.
class LiveTranslationService {
  static final LiveTranslationService instance = LiveTranslationService._();
  LiveTranslationService._();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isActive = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _sttAvailable = false;
  String _sourceLanguage = 'en';
  String _targetLanguage = 'en';

  // Callbacks
  void Function(bool active)? onTranslationStateChanged;
  void Function(String text)? onSpeechRecognized;
  void Function(String text)? onTranslationSent;
  void Function(String text)? onTranslationReceived;
  void Function(String text)? onSpoken;
  void Function(String error)? onError;

  /// Called when translated text needs to be sent via WebRTC data channel.
  /// The WebRTCCallService.sendTranslationText() should be called with this text.
  void Function(String translatedText)? onSendTranslatedText;

  // Getters
  bool get isActive => _isActive;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;

  /// Map simple language codes to TTS locale codes.
  String _toTtsLocale(String code) {
    const map = {
      'en': 'en-US', 'es': 'es-ES', 'fr': 'fr-FR', 'de': 'de-DE',
      'it': 'it-IT', 'pt': 'pt-PT', 'pt-BR': 'pt-BR', 'nl': 'nl-NL',
      'ru': 'ru-RU', 'pl': 'pl-PL', 'uk': 'uk-UA', 'tr': 'tr-TR',
      'ar': 'ar-SA', 'he': 'he-IL', 'hi': 'hi-IN', 'bn': 'bn-IN',
      'ja': 'ja-JP', 'ko': 'ko-KR', 'zh': 'zh-CN', 'zh-TW': 'zh-TW',
      'th': 'th-TH', 'vi': 'vi-VN', 'id': 'id-ID', 'ms': 'ms-MY',
      'sw': 'sw-KE', 'yo': 'yo-NG', 'ig': 'ig-NG', 'ha': 'ha-NG',
      'af': 'af-ZA', 'sv': 'sv-SE', 'da': 'da-DK', 'fi': 'fi-FI',
      'no': 'nb-NO', 'cs': 'cs-CZ', 'el': 'el-GR', 'ro': 'ro-RO',
      'hu': 'hu-HU', 'sk': 'sk-SK', 'bg': 'bg-BG', 'hr': 'hr-HR',
      'sr': 'sr-RS', 'sl': 'sl-SI', 'lt': 'lt-LT', 'lv': 'lv-LV',
      'et': 'et-EE', 'ta': 'ta-IN', 'te': 'te-IN', 'ml': 'ml-IN',
      'kn': 'kn-IN', 'mr': 'mr-IN', 'gu': 'gu-IN', 'pa': 'pa-IN',
      'ur': 'ur-PK', 'fa': 'fa-IR', 'my': 'my-MM', 'km': 'km-KH',
      'ne': 'ne-NP', 'si': 'si-LK', 'zu': 'zu-ZA',
    };
    return map[code] ?? '$code-$code';
  }

  /// Initialize STT — check availability.
  Future<bool> _initStt() async {
    if (_sttAvailable) return true;
    _sttAvailable = await _stt.initialize(
      onError: (error) => debugPrint('STT error: $error'),
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == 'done' && _isActive && !_isSpeaking) {
          _isListening = false;
          // Restart listening after a brief pause
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isActive && !_isSpeaking) _startListening();
          });
        }
      },
    );
    return _sttAvailable;
  }

  /// Initialize TTS — set up the engine.
  Future<void> _initTts() async {
    await _tts.setAwaitSpeakCompletion(false);
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      // Resume listening after TTS finishes
      if (_isActive) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_isActive && !_isListening) _startListening();
        });
      }
    });
    _tts.setErrorHandler((error) {
      _isSpeaking = false;
      debugPrint('TTS error: $error');
    });
  }

  /// Start the live translation pipeline.
  Future<void> start({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_isActive) return;

    _sourceLanguage = sourceLanguage;
    _targetLanguage = targetLanguage;
    _isActive = true;
    onTranslationStateChanged?.call(true);

    await _initStt();
    await _initTts();

    // Set TTS language to the user's language (they hear translations in their language)
    await _tts.setLanguage(_toTtsLocale(sourceLanguage));

    _startListening();
  }

  /// Start listening for speech.
  void _startListening() {
    if (!_isActive || _isSpeaking || _isListening) return;
    if (!_sttAvailable) return;

    _isListening = true;
    _stt.listen(
      onResult: (result) => _onSpeechResult(result),
      listenFor: null, // continuous
      pauseFor: const Duration(seconds: 3),
      partialResults: false, // only final results
      localeId: _toTtsLocale(_sourceLanguage),
      onSoundLevelChange: (level) {
        // Could be used for UI waveform
      },
    );
  }

  /// Handle STT result — translate and send.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isActive) return;

    final text = result.recognizedWords;
    if (text.isEmpty) {
      _isListening = false;
      if (_isActive) _startListening();
      return;
    }

    onSpeechRecognized?.call(text);

    // Only process final results (no partial)
    if (!result.finalResult) return;

    _isListening = false;

    // Translate the recognized text
    _translateAndSend(text);
  }

  /// Translate text and send it to the other person.
  Future<void> _translateAndSend(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(KoraApi.translateEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'targetLang': _targetLanguage,
              'sourceLang': _sourceLanguage,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['translatedText'] != null) {
          final translated = data['translatedText'] as String;
          onTranslationSent?.call(translated);
          onSendTranslatedText?.call(translated);
        }
      }
    } catch (e) {
      onError?.call('Translation failed: $e');
      debugPrint('Translation error: $e');
    }

    // Resume listening
    if (_isActive && !_isSpeaking) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isActive) _startListening();
      });
    }
  }

  /// Called when translated text is received from the other person via
  /// the WebRTC data channel. Plays it via TTS in the user's language.
  Future<void> onTranslatedTextReceived(String text) async {
    if (!_isActive || text.isEmpty) return;

    onTranslationReceived?.call(text);

    // Stop listening while speaking to avoid feedback
    if (_isListening) {
      _stt.stop();
      _isListening = false;
    }

    // Set TTS language to the user's language and speak
    await _tts.setLanguage(_toTtsLocale(_sourceLanguage));
    await _tts.speak(text);
    onSpoken?.call(text);
  }

  /// Change languages mid-call.
  Future<void> changeLanguages({
    String? sourceLanguage,
    String? targetLanguage,
  }) async {
    if (sourceLanguage != null) _sourceLanguage = sourceLanguage;
    if (targetLanguage != null) _targetLanguage = targetLanguage;

    if (_isActive) {
      // Restart listening with new language
      if (_isListening) {
        _stt.stop();
        _isListening = false;
      }
      await _tts.setLanguage(_toTtsLocale(_sourceLanguage));
      _startListening();
    }
  }

  /// Stop the translation pipeline.
  Future<void> stop() async {
    _isActive = false;
    _isListening = false;
    _isSpeaking = false;

    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('STT stop error: $e');
    }

    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }

    onTranslationStateChanged?.call(false);
  }

  /// Stop any ongoing TTS playback.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    stop();
  }
}
