import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/voice_vector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Extracts a VoiceVector from recorded audio using on-device DSP.
///
/// The extraction process:
/// 1. Records 30 seconds of audio (user reads a neutral prompt)
/// 2. Analyzes the audio via native DSP (autocorrelation for pitch,
///    LPC for formants, statistical analysis for jitter/shimmer/HNR)
/// 3. Returns a VoiceVector containing only mathematical features —
///    NO transcript, NO audio data, NO spoken words
///
/// Android: Method channel `com.kora.messenger/voice_vector` → Kotlin DSP
/// iOS: Method channel `com.kora.messenger/voice_vector` → Swift DSP
class VoiceVectorExtractor {
  static final VoiceVectorExtractor instance = VoiceVectorExtractor._();
  VoiceVectorExtractor._();

  static const MethodChannel _channel = MethodChannel('com.kora.messenger/voice_vector');
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;

  /// Request microphone permission.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Extract a VoiceVector from an existing audio file.
  Future<VoiceVector> extractFromAudio(String audioFilePath) async {
    try {
      if (kIsWeb) return;
      final result = await _channel.invokeMethod<Map>('extractFromAudio', {
        'audioPath': audioFilePath,
      });
      if (result != null) {
        return VoiceVector.fromJson(Map<String, dynamic>.from(result));
      }
    } on PlatformException catch (e) {
      debugPrint('[VoiceVectorExtractor] extractFromAudio error: ${e.message}');
    }
    // Fallback: return a neutral default vector
    return const VoiceVector();
  }

  /// Record a 30-second sample and extract the VoiceVector.
  ///
  /// [onProgress] receives a 0.0–1.0 progress value during recording.
  /// [maxDuration] controls how long to record (default 30s).
  Future<VoiceVector> extractFromRecording({
    Duration maxDuration = const Duration(seconds: 30),
    void Function(double progress)? onProgress,
  }) async {
    final hasPermission = await requestMicPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    // Start recording to a temp file
    final tempDir = await Directory.systemTemp.createTemp('kora_voice_vector');
    _currentRecordingPath = '${tempDir.path}/voice_sample.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentRecordingPath!,
    );

    _isRecording = true;

    // Record for maxDuration with progress updates
    final totalMs = maxDuration.inMilliseconds;
    final updateInterval = 100; // ms
    var elapsed = 0;

    final completer = Completer<VoiceVector>();
    final timer = Timer.periodic(Duration(milliseconds: updateInterval), (t) async {
      elapsed += updateInterval;
      onProgress?.call(elapsed / totalMs);

      if (elapsed >= totalMs) {
        t.cancel();
        _isRecording = false;
        await _recorder.stop();

        // Extract vector from the recording
        try {
          final vector = await extractFromAudio(_currentRecordingPath!);
          completer.complete(vector);
        } catch (e) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Cancel an ongoing recording.
  Future<void> cancelRecording() async {
    _isRecording = false;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('[VoiceVectorExtractor] cancel error: $e');
    }
  }

  /// The neutral security prompt text the user reads during recording.
  /// This is a generic phrase — the words are NOT stored in the vector.
  static const String recordingPrompt =
      'Hello, I am setting up my voice profile for Kora Messenger. '
      'This helps my friends hear translations in a voice that sounds like mine. '
      'My messages stay private and encrypted at all times.';
}
