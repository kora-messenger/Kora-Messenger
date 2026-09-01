import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native voice recording service for Kora Messenger.
///
/// Uses the native Kotlin [KoraVoiceRecorder] via a MethodChannel —
/// a MediaRecorder-based engine that captures microphone input only
/// (VOICE_COMMUNICATION source not needed — MIC source with AAC encoder).
///
/// This mirrors WhatsApp's in-app recording engine:
///   - Captures microphone input only (no system audio/notifications)
///   - Streams simulated amplitude data for the live waveform UI
///   - Supports pause / resume / cancel
///   - Output: AAC / MPEG4, 44100 Hz, 64kbps, mono
class KoraRecordingService {
  static final KoraRecordingService instance = KoraRecordingService._();
  KoraRecordingService._();

  static const _channel = MethodChannel('com.kora.messenger/voice');

  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;

  /// Amplitude stream (0.0-1.0) for the live waveform UI.
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Timer? _amplitudeTimer;
  Timer? _waveTimer;
  int _waveIndex = 0;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentPath => _currentPath;

  /// Start recording. Returns a non-empty string on success.
  Future<String> startRecording() async {
    if (_isRecording) return _currentPath ?? '';

    try {
      final path = await _channel.invokeMethod<String>('start');
      if (path == null || path.isEmpty) {
        debugPrint('[KoraRecording] Native recorder returned null path');
        return '';
      }

      _isRecording = true;
      _isPaused = false;
      _currentPath = path;

      _startAmplitudePolling();

      return path;
    } catch (e) {
      debugPrint('[KoraRecording] Start failed: $e');
      return '';
    }
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _waveTimer?.cancel();
    _waveIndex = 0;

    // Simulated waveform pattern for the live UI — the native recorder
    // uses MediaRecorder which doesn't expose real-time amplitude.
    // We use a natural-looking sine-based pattern that varies over time.
    final pattern = [
      0.25, 0.55, 0.35, 0.80, 0.42, 0.70, 0.32, 0.90,
      0.50, 0.75, 0.38, 0.62, 0.45, 0.85, 0.30, 0.65,
    ];

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isRecording || _isPaused) return;
      final value = pattern[_waveIndex % pattern.length];
      _amplitudeController.add(value);
      _waveIndex++;
    });
  }

  /// Stop recording and return the file path. Returns null if not recording.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _stopAmplitudePolling();

    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

      final path = await _channel.invokeMethod<String>('stop');
      _isRecording = false;
      _isPaused = false;
      _currentPath = null;
      return path;
    } catch (e) {
      debugPrint('[KoraRecording] Stop failed: $e');
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

      await _channel.invokeMethod('pause');
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

      await _channel.invokeMethod('resume');
      _isPaused = false;
    } catch (_) {}
  }

  /// Cancel recording — stop and delete the temp file.
  Future<void> cancelRecording() async {
    _stopAmplitudePolling();
    if (_isRecording) {
      try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

        await _channel.invokeMethod('cancel');
      } catch (_) {}
    }
    _isRecording = false;
    _isPaused = false;
    _currentPath = null;
  }

  void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _waveTimer?.cancel();
    _waveTimer = null;
  }

  void dispose() {
    _stopAmplitudePolling();
    if (_isRecording) {
      cancelRecording();
    }
  }
}
