import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';

/// In-app voice recording service for Kora Messenger.
///
/// Uses the [audio_waveforms] package's [RecorderController] — a pure
/// Flutter-managed recording engine (no custom native Kotlin code).
///
/// This mirrors WhatsApp's in-app recording engine:
///   - Captures microphone input only
///   - Streams real-time amplitude data for the live waveform UI
///   - Supports pause / resume / cancel
///   - Output: AAC / MPEG4, 44100 Hz, mono
class KoraRecordingService {
  static final KoraRecordingService instance = KoraRecordingService._();
  KoraRecordingService._();

  RecorderController? _controller;
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
  RecorderController? get controller => _controller;

  /// Lazily create the RecorderController with WhatsApp-style settings.
  RecorderController _ensureController() {
    if (_controller != null) return _controller!;
    _controller = RecorderController();
    return _controller!;
  }

  /// Start recording. Returns a non-empty string on success.
  Future<String> startRecording() async {
    if (_isRecording) return _currentPath ?? '';

    try {
      final controller = _ensureController();

      // record() internally checks permission and handles platform init
      await controller.record();

      _isRecording = true;
      _isPaused = false;
      _currentPath = null;

      _startAmplitudePolling();

      return 'recording_in_progress';
    } catch (e) {
      debugPrint('[KoraRecording] Start failed: $e');
      return '';
    }
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isRecording || _isPaused) return;
      final controller = _controller;
      if (controller == null) return;

      // audio_waveforms stores amplitudes in waveData (0.0 - 1.0)
      final waves = controller.waveData;
      if (waves.isNotEmpty) {
        _amplitudeController.add(waves.last);
      }
    });
  }

  /// Stop recording and return the file path. Returns null if not recording.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _stopAmplitudePolling();

    try {
      final controller = _controller;
      if (controller == null) return null;

      final path = await controller.stop();
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
      await _controller?.pause();
      _isPaused = true;
    } catch (_) {}
  }

  /// Resume from paused state — calling record() again resumes recording.
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
      await _controller?.record();
      _isPaused = false;
    } catch (_) {}
  }

  /// Cancel recording — stop and delete the temp file.
  Future<void> cancelRecording() async {
    _stopAmplitudePolling();
    if (_isRecording) {
      String? path;
      try {
        path = await _controller?.stop(false);
      } catch (_) {}
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
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
    _controller?.dispose();
    _controller = null;
  }
}
