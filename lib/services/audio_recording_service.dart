import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Clean audio recording service for Kora Messenger voice notes.
///
/// Uses flutter_sound to capture AAC audio. Provides real amplitude
/// data via a broadcast stream so the UI can render a live waveform
/// that actually responds to the microphone input.
class AudioRecordingService {
  static final AudioRecordingService instance = AudioRecordingService._();
  AudioRecordingService._();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;

  // Track the onProgress subscription so we can cancel it cleanly
  // before stopping the recorder — prevents the
  // "No active stream to cancel" PlatformException.
  StreamSubscription? _onProgressSub;

  // Stream controller for live amplitude data (0.0–1.0)
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentPath => _currentPath;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _recorder.openRecorder();
      _isInitialized = true;
    }
  }

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    return Permission.microphone.isGranted;
  }

  /// Start recording. Returns the file path.
  /// Throws on permission denied or recorder error.
  Future<String> startRecording() async {
    if (_isRecording) throw StateError('Already recording');

    final granted = await requestPermission();
    if (!granted) throw StateError('Microphone permission denied');

    await _ensureInitialized();

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/kora_voice_$timestamp.aac';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      sampleRate: 44100,
      bitRate: 128000,
    );

    _isRecording = true;
    _isPaused = false;
    _currentPath = path;

    // Cancel any previous onProgress subscription before starting a new one.
    // flutter_sound reuses the same EventChannel — without this, multiple
    // listen() calls accumulate and cause "No active stream to cancel"
    // PlatformException when stopRecorder() is called.
    await _onProgressSub?.cancel();
    _onProgressSub = null;

    // Stream real amplitude data from the recorder's onProgress callback
    _onProgressSub = _recorder.onProgress!.listen((e) {
      if (!_isRecording || _isPaused) return;

      // e.decibels gives dB level (typically -160 to 0)
      // Convert to 0.0-1.0 range: normalize from -60dB to 0dB
      final db = e.decibels ?? -80.0;
      final normalized = ((db + 80) / 80).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });

    return path;
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
      await _recorder.pauseRecorder();
      _isPaused = true;
    } catch (_) {
      // Some platforms don't support pause — keep recording
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
      await _recorder.resumeRecorder();
    } finally {
      _isPaused = false;
    }
  }

  /// Stop recording and return the file path. Returns null if not recording
  /// or if the file doesn't exist on disk.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    // Cancel the onProgress subscription BEFORE stopping the recorder.
    // This prevents the "No active stream to cancel" PlatformException
    // that occurs when flutter_sound tries to cancel its internal
    // EventChannel stream after it has already been torn down.
    await _onProgressSub?.cancel();
    _onProgressSub = null;

    try {
      final path = await _recorder.stopRecorder();
      _isRecording = false;
      _isPaused = false;
      _currentPath = null;

      if (path != null && !File(path).existsSync()) {
        return null;
      }
      return path;
    } catch (e) {
      // Recorder may already be stopped — reset state gracefully
      _isRecording = false;
      _isPaused = false;
      _currentPath = null;
      return null;
    }
  }

  /// Cancel recording and delete the temp file.
  Future<void> cancelRecording() async {
    // Cancel the onProgress subscription first to avoid
    // "No active stream to cancel" PlatformException.
    await _onProgressSub?.cancel();
    _onProgressSub = null;

    if (_isRecording) {
      try {
        await _recorder.stopRecorder();
      } catch (_) {}
      _isRecording = false;
      _isPaused = false;
    }

    if (_currentPath != null) {
      try {
        final file = File(_currentPath!);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    _currentPath = null;
  }

  void dispose() {
    _onProgressSub?.cancel();
    _onProgressSub = null;
    if (_isInitialized) {
      try {
        _recorder.closeRecorder();
      } catch (_) {}
      _isInitialized = false;
    }
  }
}
