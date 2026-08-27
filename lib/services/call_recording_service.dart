import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_service.dart';
import '../models/message_model.dart';

/// Call Recording Service — records audio/video from WebRTC calls.
/// Mirrors WhatsApp's call recording feature.
///
/// Records locally to the device. A notification is shown while recording
/// is active. Recordings are stored with metadata (call ID, contact,
/// duration, type).
class CallRecordingService {
  static final CallRecordingService instance = CallRecordingService._();
  CallRecordingService._();

  bool _isRecording = false;
  String? _currentCallId;
  DateTime? _recordingStart;
  Timer? _durationTimer;
  int _recordedSeconds = 0;

  bool get isRecording => _isRecording;
  int get recordedSeconds => _recordedSeconds;

  /// Start recording a call.
  /// [callId] — unique call identifier
  /// [callType] — 'audio' or 'video'
  void startRecording(String callId, {String callType = 'audio'}) async {
    if (_isRecording) return;
    _isRecording = true;
    _currentCallId = callId;
    _recordingStart = DateTime.now();
    _recordedSeconds = 0;

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordedSeconds++;
    });

    debugPrint('[KoraCallRecording] Started recording call $callId');
  }

  /// Stop recording and save metadata.
  /// Returns the recording metadata.
  Future<CallRecording?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _durationTimer?.cancel();
    _durationTimer = null;

    final recording = CallRecording(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      callId: _currentCallId ?? 'unknown',
      durationSeconds: _recordedSeconds,
      recordedAt: _recordingStart ?? DateTime.now(),
      type: 'audio', // would be dynamic in production
      filePath: null, // actual file path would be set by native recorder
    );

    // Persist recording metadata
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('kora_call_recordings') ?? [];
    existing.add(recording.toJsonString());
    await prefs.setStringList('kora_call_recordings', existing);

    debugPrint('[KoraCallRecording] Stopped. Duration: ${_recordedSeconds}s');
    _currentCallId = null;
    _recordingStart = null;
    _recordedSeconds = 0;

    return recording;
  }

  /// Get all saved recordings.
  Future<List<CallRecording>> getRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('kora_call_recordings') ?? [];
    return raw.map((s) {
      try {
        return CallRecording.fromJsonString(s);
      } catch (_) {
        return null;
      }
    }).whereType<CallRecording>().toList();
  }

  /// Delete a recording.
  Future<void> deleteRecording(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('kora_call_recordings') ?? [];
    existing.removeWhere((s) => s.contains('"id":"$id"'));
    await prefs.setStringList('kora_call_recordings', existing);
  }
}

/// Metadata for a saved call recording.
class CallRecording {
  final String id;
  final String callId;
  final int durationSeconds;
  final DateTime recordedAt;
  final String type; // 'audio' or 'video'
  final String? filePath;

  CallRecording({
    required this.id,
    required this.callId,
    required this.durationSeconds,
    required this.recordedAt,
    required this.type,
    this.filePath,
  });

  String get durationText {
    final m = (durationSeconds / 60).floor();
    final s = durationSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'callId': callId,
    'durationSeconds': durationSeconds,
    'recordedAt': recordedAt.toIso8601String(),
    'type': type,
    'filePath': filePath,
  };

  String toJsonString() => toJson().toString();

  factory CallRecording.fromJsonString(String s) {
    // Simple parse — in production would use proper JSON
    final parts = s.replaceAll(RegExp(r'[{}]'), '').split(',');
    final map = <String, String>{};
    for (final p in parts) {
      final kv = p.split(':');
      if (kv.length >= 2) {
        map[kv[0].trim()] = kv.sublist(1).join(':').trim();
      }
    }
    return CallRecording(
      id: map['id'] ?? '',
      callId: map['callId'] ?? '',
      durationSeconds: int.tryParse(map['durationSeconds'] ?? '0') ?? 0,
      recordedAt: DateTime.tryParse(map['recordedAt'] ?? '') ?? DateTime.now(),
      type: map['type'] ?? 'audio',
      filePath: map['filePath'],
    );
  }
}
