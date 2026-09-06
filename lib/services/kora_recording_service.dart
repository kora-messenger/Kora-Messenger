import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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

    // Real hardware amplitude (Telegram-parity): poll the native
    // MediaRecorder's maxAmplitude over the method channel and
    // normalize to 0.0-1.0 with a perceptual gain curve so the
    // live waveform reacts to how loud the user actually speaks.
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isRecording || _isPaused) return;
      _pollAmplitude();
    });
  }

  /// One real-amplitude poll cycle. maxAmplitude is 0-32767 raw;
  /// speech typically peaks 1000-8000, so we use a sqrt gain curve
  /// (perceptual, like Telegram's waveform downscaling in audio.c)
  /// and clamp to a 0.03 floor so bars stay slightly visible.
  Future<void> _pollAmplitude() async {
    if (kIsWeb) {
      _amplitudeController.add(0.3);
      return;
    }
    try {
      final raw = await _channel.invokeMethod<int>('amplitude');
      final amp = (raw ?? 0).clamp(0, 32767).toDouble();
      final normalized = math.sqrt(amp / 32767.0);
      final value = (normalized * 1.35).clamp(0.03, 1.0);
      _amplitudeController.add(value);
    } catch (_) {
      // Native poll failed — emit floor so the UI keeps moving.
      _amplitudeController.add(0.03);
    }
  }

  /// Stop recording and return the file path. Returns null if not recording.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _stopAmplitudePolling();

    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      _isRecording = false;
      return null;
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
  }

  void dispose() {
    _stopAmplitudePolling();
    if (_isRecording) {
      cancelRecording();
    }
  }
}
