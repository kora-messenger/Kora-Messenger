import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Native audio recording service for Kora Messenger voice notes.
///
/// Uses a native Android MediaRecorder with VOICE_COMMUNICATION audio source:
///   - Captures ONLY the device microphone (never system audio / REMOTE_SUBMIX)
///   - Enables Android's built-in echo cancellation
///   - Enables automatic gain control (AGC)
///   - Enables noise suppression
///
/// Output: MPEG_4 / AAC, 44100 Hz, 128 kbps, mono
///
/// Amplitude data for the live waveform is streamed from the native
/// getMaxAmplitude() poll at 50ms intervals.
///
/// Architecture:
///   User's microphone -> VOICE_COMMUNICATION source -> AAC encoder -> voice-note file
///   NOT: system audio mix -> recorder
class NativeAudioRecordingService {
  static final NativeAudioRecordingService instance =
      NativeAudioRecordingService._();
  NativeAudioRecordingService._();

  static const _methodChannel =
      MethodChannel('com.kora.messenger/voice_recorder');
  static const _eventChannel =
      EventChannel('com.kora.messenger/voice_recorder_events');

  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;

  // Amplitude stream (0.0-1.0) for the live waveform UI
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  StreamSubscription? _eventSub;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentPath => _currentPath;

  /// Start listening to native amplitude events.
  void _startAmplitudeListener() {
    _eventSub?.cancel();
    _eventSub = _eventChannel.receiveBroadcastStream().listen((amplitude) {
      if (amplitude is double) {
        _amplitudeController.add(amplitude);
      } else if (amplitude is num) {
        _amplitudeController.add(amplitude.toDouble());
      }
    });
  }

  void _stopAmplitudeListener() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  /// Start recording. Returns the file path, or empty string on failure.
  ///
  /// The native Android side handles:
  ///   - Audio source: VOICE_COMMUNICATION (mic only, echo cancellation, AGC, noise suppression)
  ///   - Output path: app cache directory
  ///   - Amplitude polling: 50ms intervals via EventChannel
  Future<String> startRecording() async {
    if (_isRecording) return _currentPath ?? '';

    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return '';
    }

      final result = await _methodChannel.invokeMethod<String>('startRecording');

      if (result != null && result.isNotEmpty) {
        _isRecording = true;
        _isPaused = false;
        _currentPath = result;
        _startAmplitudeListener();
        return result;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Stop recording and return the file path. Returns null if not recording
  /// or if the file doesn't exist.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _stopAmplitudeListener();

    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      _isRecording = false;
      return null;
    }

      final path = await _methodChannel.invokeMethod<String>('stopRecording');
      _isRecording = false;
      _isPaused = false;
      _currentPath = null;
      return path;
    } catch (e) {
      _isRecording = false;
      _isPaused = false;
      _currentPath = null;
      return null;
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

      await _methodChannel.invokeMethod('pauseRecording');
      _isPaused = true;
    } catch (_) {}
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

      await _methodChannel.invokeMethod('resumeRecording');
      _isPaused = false;
    } catch (_) {}
  }

  /// Cancel recording and delete the temp file.
  Future<void> cancelRecording() async {
    _stopAmplitudeListener();
    if (_isRecording) {
      try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

        await _methodChannel.invokeMethod('cancelRecording');
      } catch (_) {}
    }
    _isRecording = false;
    _isPaused = false;
    _currentPath = null;
  }

  void dispose() {
    _stopAmplitudeListener();
    if (_isRecording) {
      cancelRecording();
    }
  }
}
