import 'dart:async';

class AudioRecordingService {
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    _isRecording = false;
    return null;
  }

  Future<void> cancelRecording() async {
    _isRecording = false;
  }

  void dispose() {}
}
