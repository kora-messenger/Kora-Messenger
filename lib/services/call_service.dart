import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log.dart';
import '../models/chat_models.dart';

/// Manages call history with local persistence (SharedPreferences).
///
/// Calls are logged when a user makes or receives a voice/video call
/// through the [WebRTCCallService]. The Calls tab on the Home screen
/// reads from this service.
class CallService {
  static final CallService instance = CallService._();
  CallService._();

  static const _kKey = 'kora_call_logs';
  static const _kSeeded = 'kora_calls_seeded';

  List<CallLog> _logs = [];
  bool _loaded = false;

  // ── Load / Save ────────────────────────────────────────────

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(_kSeeded) ?? false;

    if (!seeded) {
      _seedDemoCalls();
      await _persist();
      await prefs.setBool(_kSeeded, true);
    } else {
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _logs = list.map((e) => CallLog.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_logs.map((l) => l.toJson()).toList()));
  }

  // ── Public API ─────────────────────────────────────────────

  List<CallLog> getLogs() => List.unmodifiable(_logs);

  Future<void> addLog(CallLog log) async {
    _logs.insert(0, log);
    await _persist();
  }

  /// Log an outgoing call.
  Future<void> logOutgoingCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
    int? durationSeconds,
  }) async {
    await addLog(CallLog(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      contactName: contactName,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      type: type,
      status: CallStatus.outgoing,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
    ));
  }

  /// Log an incoming call.
  Future<void> logIncomingCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
    int? durationSeconds,
    bool missed = false,
  }) async {
    await addLog(CallLog(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      contactName: contactName,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      type: type,
      status: missed ? CallStatus.missed : CallStatus.incoming,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
    ));
  }

  /// Log a missed call.
  Future<void> logMissedCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
  }) async {
    await logIncomingCall(
      contactName: contactName,
      type: type,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      missed: true,
    );
  }

  Future<void> clearAll() async {
    _logs.clear();
    await _persist();
  }

  // ── Seed data ─────────────────────────────────────────────

  void _seedDemoCalls() {
    final now = DateTime.now();
    _logs = [
      CallLog(
        id: 'call_1',
        contactName: 'David Okoro',
        avatarUrl: null,
        badge: KoraBadgeType.premiumBlue,
        type: CallType.video,
        status: CallStatus.missed,
        timestamp: now.subtract(const Duration(minutes: 35)),
      ),
      CallLog(
        id: 'call_2',
        contactName: 'Amara Chukwu',
        type: CallType.voice,
        status: CallStatus.outgoing,
        timestamp: now.subtract(const Duration(hours: 2)),
        durationSeconds: 184,
      ),
      CallLog(
        id: 'call_3',
        contactName: 'Grace Adeyemi',
        type: CallType.voice,
        status: CallStatus.incoming,
        timestamp: now.subtract(const Duration(hours: 5)),
        durationSeconds: 92,
      ),
    ];
  }
}
