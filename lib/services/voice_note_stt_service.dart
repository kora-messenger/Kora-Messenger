import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Dedicated on-device speech-to-text capture service for VOICE NOTE recording.
///
/// This service runs ALONGSIDE the `flutter_sound` audio recorder (used elsewhere
/// in the app for voice notes) to capture a live transcript of what the user says
/// while they record, purely for the on-device translate-before-send feature.
/// It does NOT affect the actual audio file being recorded.
class VoiceNoteSttService {
  static final VoiceNoteSttService instance = VoiceNoteSttService._();
  VoiceNoteSttService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _isListening = false;
  String _transcript = '';
  String _baseTranscript = '';

  /// Whether the device supports on-device speech recognition.
  bool get isAvailable => _available;

  /// Whether STT is currently listening to the microphone.
  bool get isListening => _isListening;

  /// Initialize (if needed) and start listening using the system default locale.
  ///
  /// Does NOT pass a `localeId` to let the package auto-select the device's default language.
  /// Accumulates recognized words into internal transcript.
  /// Returns [true] if listening started, or [false] if STT initialization/listening failed.
  /// Never throws exceptions.
  Future<bool> start() async {
    _transcript = '';
    _baseTranscript = '';

    if (!_available) {
      try {
        _available = await _speech.initialize(
          onError: (error) {
            debugPrint('[VoiceNoteSTT] Error: ${error.errorMsg}');
          },
          onStatus: (status) {
            debugPrint('[VoiceNoteSTT] Status: $status');
            // Handle silence timeout auto-restart pattern
            if (status == 'notListening' && _isListening) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_isListening) _restart();
              });
            }
          },
        );
      } catch (e) {
        debugPrint('[VoiceNoteSTT] Exception during initialize: $e');
        _available = false;
        return false;
      }
    }

    if (!_available) {
      debugPrint('[VoiceNoteSTT] Speech recognition unavailable on device');
      return false;
    }

    _isListening = true;

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          autoPunctuation: true,
        ),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            if (_baseTranscript.isNotEmpty) {
              _transcript = '${_baseTranscript} ${result.recognizedWords}'.trim();
            } else {
              _transcript = result.recognizedWords;
            }
          }
        },
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceNoteSTT] Exception during listen: $e');
      _isListening = false;
      return false;
    }
  }

  /// Auto-restarts listening after a silence pause to maintain continuous capture.
  Future<void> _restart() async {
    if (!_isListening || !_available) return;

    if (_transcript.isNotEmpty) {
      _baseTranscript = _transcript;
    }

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          autoPunctuation: true,
        ),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            if (_baseTranscript.isNotEmpty) {
              _transcript = '${_baseTranscript} ${result.recognizedWords}'.trim();
            } else {
              _transcript = result.recognizedWords;
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[VoiceNoteSTT] Restart failed: $e');
    }
  }

  /// Stops listening and returns the final accumulated transcript.
  ///
  /// Returns an empty string if nothing was captured or STT was unavailable.
  /// Safe to call even if [start] was never called or failed.
  Future<String> stop() async {
    _isListening = false;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('[VoiceNoteSTT] Exception during stop: $e');
    }
    final finalTranscript = _transcript.trim();
    return finalTranscript;
  }
}
