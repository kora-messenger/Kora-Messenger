import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/voice_vector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Low-latency real-time audio DSP service for modifying TTS output
/// to match a target voice vector using native DSP processing.
///
/// Android: Uses SoundTouch library via method channel for pitch-shift
///          and formant filtering.
/// iOS: Uses AVAudioEngine + AUAudioUnit (vDSP) for real-time
///      pitch/formant modification.
///
/// Latency target: < 50ms for real-time call use.
class RealtimeDspService {
  static final RealtimeDspService instance = RealtimeDspService._();
  RealtimeDspService._();

  static const MethodChannel _channel = MethodChannel('com.kora.messenger/realtime_dsp');

  VoiceVector? _currentVoiceVector;
  bool _isProcessing = false;

  VoiceVector? get currentVoiceVector => _currentVoiceVector;
  bool get isProcessing => _isProcessing;

  /// Configure DSP parameters from a VoiceVector.
  Future<void> applyVoiceVector(VoiceVector vector) async {
    _currentVoiceVector = vector;
    try {
      if (kIsWeb) return;
      await _channel.invokeMethod('applyVoiceVector', vector.toJson());
    } on PlatformException catch (e) {
      debugPrint('[RealtimeDsp] applyVoiceVector error: ${e.message}');
    }
  }

  /// Process an audio file offline — apply pitch shift and formant filter.
  Future<String?> processAudioFile(String inputPath, String outputPath, {VoiceVector? vector}) async {
    try {
      final v = vector ?? _currentVoiceVector;
      if (kIsWeb) return null;
      final result = await _channel.invokeMethod<String>('processAudioFile', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'voiceVector': v?.toJson(),
      });
      return result ?? outputPath;
    } on PlatformException catch (e) {
      debugPrint('[RealtimeDsp] processAudioFile error: ${e.message}');
      return null;
    }
  }

  /// Begin real-time audio processing pipeline.
  Future<void> startRealtimeProcessing() async {
    try {
      if (kIsWeb) return;
      await _channel.invokeMethod('startRealtimeProcessing');
      _isProcessing = true;
    } on PlatformException catch (e) {
      debugPrint('[RealtimeDsp] start error: ${e.message}');
    }
  }

  /// Stop real-time audio processing.
  Future<void> stopRealtimeProcessing() async {
    try {
      if (kIsWeb) return;
      await _channel.invokeMethod('stopRealtimeProcessing');
      _isProcessing = false;
    } on PlatformException catch (e) {
      debugPrint('[RealtimeDsp] stop error: ${e.message}');
    }
  }

  /// Take TTS output audio and apply voice modification to match target voice.
  /// Returns the path to the processed audio file.
  /// Falls back to the original TTS audio if DSP fails.
  Future<String> processTtsOutput(String ttsAudioPath, VoiceVector targetVoice) async {
    final outputPath = '${ttsAudioPath.replaceAll(RegExp(r'\.[^.]+$'), '')}_dsp.wav';
    try {
      await applyVoiceVector(targetVoice);
      if (kIsWeb) return ttsAudioPath;
      final result = await _channel.invokeMethod<String>('processTtsOutput', {
        'ttsAudioPath': ttsAudioPath,
        'outputPath': outputPath,
        'voiceVector': targetVoice.toJson(),
      });
      return result ?? outputPath;
    } on PlatformException catch (e) {
      debugPrint('[RealtimeDsp] processTtsOutput error: ${e.message}');
      // Graceful fallback: return unmodified TTS audio
      return ttsAudioPath;
    }
  }
}
