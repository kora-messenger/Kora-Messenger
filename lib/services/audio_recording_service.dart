import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real audio recording service for Kora Messenger voice notes.
///
/// Uses the `record` package (v4 API) to capture audio from the device microphone,
/// saves to a temp file, and returns the file path for playback/storage.
class AudioRecordingService {
  static final AudioRecordingService instance = AudioRecordingService._();
  AudioRecordingService._();

  final Record _recorder = Record();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;

  /// Request microphone permission.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording audio. Returns the file path where audio is saved.
  /// Throws if already recording or permission denied.
  Future<String> startRecording() async {
    if (_isRecording) {
      throw StateError('Already recording');
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission denied');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/kora_voice_$timestamp.m4a';

    await _recorder.start(
      path: path,
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      samplingRate: 44100,
    );

    _isRecording = true;
    _currentPath = path;
    return path;
  }

  /// Stop recording and return the file path.
  /// Returns null if not recording.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    _currentPath = null;
    return path;
  }

  /// Cancel recording and delete the file.
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
    _currentPath = null;
  }

  /// Get the amplitude of the current recording (for waveform).
  /// Returns a value 0.0 - 1.0.
  Future<double> getAmplitude() async {
    if (!_isRecording) return 0.0;
    try {
      final amp = await _recorder.getAmplitude();
      // Normalize dBFS (-60 to 0) to 0.0 - 1.0
      final normalized = (amp.current + 60) / 60;
      return normalized.clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  /// Check if the microphone is available.
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  void dispose() {
    _recorder.dispose();
  }
}
