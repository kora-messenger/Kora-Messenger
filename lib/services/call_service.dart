import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log.dart';
import '../models/chat_models.dart';

/// Manages call history with local persistence (SharedPreferences).
///
/// Calls are logged when a user makes or receives a voice/video call
/// through the [WebRTCCallService]. The Calls tab on the Home screen
/// reads from this service. Real calls only — no demo/simulated
/// history (matches the reference app: fresh installs show the
/// "No calls yet" empty state until a real call happens).
class CallService {
  static final CallService instance = CallService._();
  CallService._();

  static const _kKey = 'kora_call_logs';

  List<CallLog> _logs = [];
  bool _loaded = false;

  /// Legacy demo entries seeded by early builds ('call_1'..'call_3').
  /// Purged on load so upgrading installs never show fake history —
  /// the reference app only ever shows real calls.
  static const _legacyDemoIds = {'call_1', 'call_2', 'call_3'};

  // ── Load / Save ────────────────────────────────────────────

  Future<void> init() async {
    if (_loaded) return;
    await _ensureLoaded();
  }

  /// Loads persisted logs. Safe to call from anywhere (call screens
  /// can log before the Calls tab ever calls [init]) — without this,
  /// persisting a new log would wipe the stored history.
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _logs = list.map((e) => CallLog.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _logs = [];
      }
    }

    // One-time purge of demo entries from older builds.
    if (_logs.any((l) => _legacyDemoIds.contains(l.id))) {
      _logs.removeWhere((l) => _legacyDemoIds.contains(l.id));
      await _persist();
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
    await _ensureLoaded();
    _logs.insert(0, log);
    await _persist();
  }

  /// Update call feedback/rating for a CallLog entry.
  Future<void> updateCallRating({
    required String callId,
    required int rating,
    String? feedback,
  }) async {
    await _ensureLoaded();
    final index = _logs.indexWhere((l) => l.id == callId);
    if (index != -1) {
      _logs[index] = _logs[index].copyWith(
        rating: rating,
        feedback: feedback,
      );
      await _persist();
    } else if (_logs.isNotEmpty) {
      // Fallback: update most recent log if ID not explicitly matched
      _logs[0] = _logs[0].copyWith(
        rating: rating,
        feedback: feedback,
      );
      await _persist();
    }
  }

  /// Log an outgoing call. Returns the generated call log ID.
  Future<String> logOutgoingCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
    int? durationSeconds,
  }) async {
    final id = 'call_${DateTime.now().millisecondsSinceEpoch}';
    await addLog(CallLog(
      id: id,
      contactName: contactName,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      type: type,
      status: CallStatus.outgoing,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
    ));
    return id;
  }

  /// Log an incoming call. Returns the generated call log ID.
  Future<String> logIncomingCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
    int? durationSeconds,
    bool missed = false,
  }) async {
    final id = 'call_${DateTime.now().millisecondsSinceEpoch}';
    await addLog(CallLog(
      id: id,
      contactName: contactName,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      type: type,
      status: missed ? CallStatus.missed : CallStatus.incoming,
      timestamp: DateTime.now(),
      durationSeconds: durationSeconds,
    ));
    return id;
  }

  /// Log a missed call.
  Future<String> logMissedCall({
    required String contactName,
    CallType type = CallType.voice,
    String? avatarUrl,
    KoraBadgeType? badge,
  }) async {
    return await logIncomingCall(
      contactName: contactName,
      type: type,
      avatarUrl: avatarUrl,
      badge: badge ?? KoraBadgeType.none,
      missed: true,
    );
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _logs.clear();
    await _persist();
  }
}
