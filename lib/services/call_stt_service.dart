import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// On-device speech-to-text service for calls.
///
/// Uses the `speech_to_text` package to transcribe the local user's
/// speech in real-time during a call. Recognized words are streamed
/// via a callback so the call screen can send them over the WebRTC
/// data channel to the remote peer.
///
/// Key design decisions:
/// - Only transcribes the LOCAL user (what they say into the mic).
/// - Does NOT interfere with the WebRTC audio stream — both can use
///   the microphone simultaneously on Android/iOS.
/// - Stops cleanly when translation is toggled off or the call ends.
/// - Falls back gracefully if STT is unavailable (older devices,
///   missing permissions, etc.).
class CallSttService {
  static final CallSttService instance = CallSttService._();
  CallSttService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _isListening = false;
  String _currentLocale = 'en-US';

  /// Called whenever a chunk of recognized speech is available.
  /// The call screen sends this text over the WebRTC data channel.
  void Function(String text, bool isFinal)? onTranscript;

  /// Called if STT encounters an error or becomes unavailable.
  void Function(String error)? onError;

  /// Whether the device supports on-device speech recognition.
  bool get isAvailable => _available;

  /// Whether STT is currently listening to the microphone.
  bool get isListening => _isListening;

  /// Initialize the speech recognizer. Must be called before [start].
  Future<bool> init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onError: (error) {
        debugPrint('[CallSTT] Error: ${error.errorMsg}');
        onError?.call(error.errorMsg);
      },
      onStatus: (status) {
        debugPrint('[CallSTT] Status: $status');
        // If listening stops unexpectedly (e.g. pause due to silence),
        // restart it — we want continuous recognition during a call.
        if (status == 'notListening' && _isListening) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isListening) _restart();
          });
        }
      },
    );
    return _available;
  }

  /// Set the recognition locale (e.g. 'en-US', 'es-ES', 'fr-FR').
  /// Should match the user's selected "Your language" in the translation sheet.
  void setLocale(String localeCode) {
    _currentLocale = localeCode;
  }

  /// Start listening to the microphone and transcribing speech.
  Future<void> start() async {
    if (!_available) {
      final ok = await init();
      if (!ok) {
        onError?.call('Speech recognition not available on this device');
        return;
      }
    }

    if (_isListening) return;

    _isListening = true;

    await _speech.listen(
      localeId: _currentLocale,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        onTranscript?.call(result.recognizedWords, result.finalResult);
      },
    );
  }

  /// Restart listening after a silence pause — keeps recognition
  /// continuous during the call without requiring the user to tap anything.
  Future<void> _restart() async {
    if (!_isListening || !_available) return;

    try {
      await _speech.listen(
        localeId: _currentLocale,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (result) {
          onTranscript?.call(result.recognizedWords, result.finalResult);
        },
      );
    } catch (e) {
      debugPrint('[CallSTT] Restart failed: $e');
    }
  }

  /// Stop listening and release the microphone.
  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Fully release resources.
  Future<void> dispose() async {
    _isListening = false;
    await _speech.cancel();
  }
}
