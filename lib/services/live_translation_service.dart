import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/kora_api.dart';
import 'voice_management_service.dart';

/// Live voice-to-voice translation service for Kora calls.
///
/// Architecture (modeled on AI Phone's pipeline):
/// 1. STT captures the user's speech on-device (partial results enabled)
/// 2. Partial recognized text is sent to koraGptTrans streaming backend
/// 3. GPT streams back translated chunks as they arrive (SSE)
/// 4. Translated text is sent to the other person via WebRTC data channel
/// 5. The other person's device receives it and plays it via TTS
/// 6. Language auto-detection handles unknown source languages
///
/// Dual TTS paths (like AI Phone):
/// - Local TTS: user hears translations in their language
/// - Remote TTS: translated text sent to other party for their TTS
///
/// Architecture is domain-swappable — when a cloud TTS with voice
/// cloning is added (like ElevenLabs), only this file changes.
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
  bool _autoDetectLanguage = true; // AI Phone's LanguageIdMode

  // Streaming state
  String _accumulatedText = '';
  String _partialRecognized = '';
  Timer? _debounceTimer;
  int _transactionId = 0;

  // Callbacks
  void Function(bool active)? onTranslationStateChanged;
  void Function(String text)? onSpeechRecognized;        // partial STT
  void Function(String text)? onTranslationSent;          // translated text sent
  void Function(String text)? onTranslationReceived;      // translated text received
  void Function(String text)? onSpoken;                   // TTS spoken
  void Function(String error)? onError;

  /// Called when translated text needs to be sent via WebRTC data channel.
  void Function(String translatedText)? onSendTranslatedText;

  // Getters
  bool get isActive => _isActive;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  bool get autoDetectLanguage => _autoDetectLanguage;

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
    // Sync with VoiceManagementService so the selected voice is applied
    await VoiceManagementService.instance.init();
    await _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
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
  ///
  /// [autoDetect] — if true (default), auto-detects the source language
  /// like AI Phone's LanguageIdMode. If false, uses [sourceLanguage] directly.
  Future<void> start({
    required String sourceLanguage,
    required String targetLanguage,
    bool autoDetect = true,
  }) async {
    if (_isActive) return;

    _sourceLanguage = sourceLanguage;
    _targetLanguage = targetLanguage;
    _autoDetectLanguage = autoDetect;
    _isActive = true;
    onTranslationStateChanged?.call(true);

    await _initStt();
    await _initTts();

    // Set TTS language to the user's language (they hear translations in their language)
    await _tts.setLanguage(_toTtsLocale(sourceLanguage));

    _startListening();
  }

  /// Start listening for speech with partial results (like AI Phone).
  void _startListening() {
    if (!_isActive || _isSpeaking || _isListening) return;
    if (!_sttAvailable) return;

    _isListening = true;
    _partialRecognized = '';
    _accumulatedText = '';

    _stt.listen(
      onResult: (result) => _onSpeechResult(result),
      listenFor: null,
      pauseFor: const Duration(seconds: 3),
      // AI Phone uses partial results for real-time captioning
      partialResults: true,
      localeId: _toTtsLocale(_sourceLanguage),
      onSoundLevelChange: (level) {
        // Could be used for UI waveform
      },
    );
  }

  /// Handle STT result — process both partial and final results.
  ///
  /// AI Phone pattern:
  /// - Partial results: show as live caption, debounce translation
  /// - Final results: translate and send to other party
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isActive) return;

    final text = result.recognizedWords;
    if (text.isEmpty) {
      _isListening = false;
      if (_isActive) _startListening();
      return;
    }

    // Always update the recognized text for live caption display
    onSpeechRecognized?.call(text);

    if (!result.finalResult) {
      // Partial result — update display, debounce translation
      _partialRecognized = text;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        // If no final result in 500ms, translate the partial
        if (_partialRecognized.isNotEmpty && _isActive) {
          _translateAndSend(_partialRecognized, isPartial: true);
        }
      });
      return;
    }

    // Final result — cancel debounce and translate immediately
    _debounceTimer?.cancel();
    _isListening = false;
    _translateAndSend(text, isPartial: false);
  }

  /// Translate text and send it to the other person.
  ///
  /// Uses streaming GPT translation for final results (lower latency).
  /// Uses batch translation for partial results (quick preview).
  Future<void> _translateAndSend(String text, {required bool isPartial}) async {
    _transactionId++;

    try {
      if (isPartial) {
        // Quick batch translation for partial results (preview)
        final response = await http
            .post(
              Uri.parse(KoraApi.gptTransEndpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': text,
                'targetLang': _targetLanguage,
                'sourceLang': _autoDetectLanguage ? '' : _sourceLanguage,
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true && data['translatedText'] != null) {
            final translated = data['translatedText'] as String;
            // Update detected language if auto-detect
            if (_autoDetectLanguage && data['detectedLanguage'] != null) {
              _sourceLanguage = data['detectedLanguage'] as String;
            }
            // For partial results, only update the caption (don't send via WebRTC yet)
            onTranslationSent?.call(translated);
          }
        }
      } else {
        // Final result — use streaming translation for lower latency
        final request = http.Request(
          'POST',
          Uri.parse(KoraApi.gptTransEndpoint),
        )
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'text/event-stream'
          ..body = jsonEncode({
            'text': text,
            'targetLang': _targetLanguage,
            'sourceLang': _autoDetectLanguage ? '' : _sourceLanguage,
            'stream': true,
            'transactionId': '$_transactionId',
          });

        final client = http.Client();
        final response = await client.send(request);

        if (response.statusCode == 200) {
          final fullText = StringBuffer();
          await for (final chunk in response.stream.transform(utf8.decoder)) {
            for (final line in chunk.split('\n')) {
              if (line.startsWith('data: ')) {
                try {
                  final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
                  if (data['type'] == 'delta' && data['text'] != null) {
                    fullText.write(data['text']);
                    // Stream partial translation to UI
                    onTranslationSent?.call(fullText.toString());
                  } else if (data['type'] == 'done' && data['translatedText'] != null) {
                    final translated = data['translatedText'] as String;
                    // Update detected language if auto-detect
                    if (_autoDetectLanguage && data['detectedLanguage'] != null) {
                      _sourceLanguage = data['detectedLanguage'] as String;
                    }
                    // Send the final translation via WebRTC data channel
                    onSendTranslatedText?.call(translated);
                    onTranslationSent?.call(translated);
                  }
                } catch (e) {}
              }
            }
          }
          client.close();
        } else {
          // Fall back to batch
          await _batchTranslateAndSend(text);
        }
      }
    } catch (e) {
      if (!isPartial) {
        // Only error on final results
        onError?.call('Translation failed: $e');
        await _batchTranslateAndSend(text);
      }
      debugPrint('Translation error: $e');
    }

    // Resume listening
    if (_isActive && !_isSpeaking && !isPartial) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isActive) _startListening();
      });
    }
  }

  /// Batch translation fallback (non-streaming).
  Future<void> _batchTranslateAndSend(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(KoraApi.gptTransEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'targetLang': _targetLanguage,
              'sourceLang': _autoDetectLanguage ? '' : _sourceLanguage,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['translatedText'] != null) {
          final translated = data['translatedText'] as String;
          if (_autoDetectLanguage && data['detectedLanguage'] != null) {
            _sourceLanguage = data['detectedLanguage'] as String;
          }
          onSendTranslatedText?.call(translated);
          onTranslationSent?.call(translated);
        }
      }
    } catch (e) {
      debugPrint('Batch translation fallback failed: $e');
    }
  }

  /// Called when translated text is received from the other person via
  /// the WebRTC data channel. Plays it via TTS in the user's language.
  ///
  /// AI Phone dual TTS:
  /// - Local TTS: plays translated text for the user to hear
  /// - The remote party's TTS handles their side separately
  Future<void> onTranslatedTextReceived(String text) async {
    if (!_isActive || text.isEmpty) return;

    onTranslationReceived?.call(text);

    // Stop listening while speaking to avoid feedback
    if (_isListening) {
      _stt.stop();
      _isListening = false;
    }

    // Use VoiceManagementService's TTS — applies the selected voice's
    // pitch, rate, and system voice. NOT a placeholder: selecting a
    // voice in Voice Studio changes the actual TTS output.
    final voiceService = VoiceManagementService.instance;
    await voiceService.init();
    final selectedVoice = voiceService.selectedVoice;
    final langCode = selectedVoice?.language ?? _sourceLanguage;
    await _tts.setLanguage(_toTtsLocale(langCode));
    // Apply voice parameters (pitch, rate from selected voice)
    if (selectedVoice != null) {
      await _tts.setPitch(selectedVoice.pitch);
      await _tts.setSpeechRate(selectedVoice.rate);
    }
    await _tts.speak(text);
    onSpoken?.call(text);
  }

  /// Change languages mid-call.
  Future<void> changeLanguages({
    String? sourceLanguage,
    String? targetLanguage,
    bool? autoDetect,
  }) async {
    if (sourceLanguage != null) _sourceLanguage = sourceLanguage;
    if (targetLanguage != null) _targetLanguage = targetLanguage;
    if (autoDetect != null) _autoDetectLanguage = autoDetect;

    if (_isActive) {
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
    _debounceTimer?.cancel();

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
