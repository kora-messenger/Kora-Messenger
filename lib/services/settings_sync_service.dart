import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/kora_api.dart';
import 'session_manager.dart';

/// Telegram-style cloud settings.
///
/// All user preferences (theme, notifications, privacy, wallpapers,
/// per-chat settings, ...) live in the cloud alongside the account.
/// Log in on any device and everything appears — no restore flow.
///
/// How it works:
///  * [syncNow] runs a pull-then-push cycle: cloud values are applied
///    locally (cloud wins), then the full local blob is pushed so keys
///    the cloud didn't have get created.
///  * A periodic timer keeps devices converged (default: 10 minutes).
///  * Device-specific keys (session, device id, backup PIN, network
///    stats, pending uploads) are never synced.
class SettingsSyncService {
  SettingsSyncService._();
  static final SettingsSyncService instance = SettingsSyncService._();

  Timer? _timer;
  bool _syncing = false;

  /// Keys/prefixes that must NEVER leave this device.
  static const List<String> _excludedKeys = [
    'kora_session',
    'kora_last_email',
    'user_email',
    'kora_device_id',
    'kora_device_name',
    'kora_backup_pin',
    'kora_voice_uploads',
    'kora_service_notif_last_seen',
    'kora_welcome_sent',
    'kora_expiry_sent',
    'kora_premium_trial_start',
    'kora_ai_active_conversation',
    'kora_support_active_conversation',
    'demo_phone_verify_code',
  ];

  static const List<String> _excludedPrefixes = [
    'net_', // network usage stats (per-device)
    'kora_msgs_', // chat message stores (handled by ChatSyncService)
  ];

  bool _isExcluded(String key) {
    if (_excludedKeys.contains(key)) return true;
    if (key.contains('token') || key.contains('password')) return true;
    for (final prefix in _excludedPrefixes) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  Map<String, dynamic>? _encodeValue(Object? v) {
    if (v is bool) return {'_t': 'b', '_v': v};
    if (v is int) return {'_t': 'i', '_v': v};
    if (v is double) return {'_t': 'd', '_v': v};
    if (v is String) return {'_t': 's', '_v': v};
    if (v is List && v.every((e) => e is String)) {
      return {'_t': 'l', '_v': v};
    }
    return null; // unsupported type — skip
  }

  /// Collect every syncable preference as {key: {_t, _v}}.
  Future<Map<String, dynamic>> _collectSyncable(SharedPreferences prefs) async {
    final out = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_isExcluded(key)) continue;
      final wrapped = _encodeValue(prefs.get(key));
      if (wrapped == null) continue;
      final v = wrapped['_v'];
      if (v == null || (v is String && v.isEmpty)) continue;
      out[key] = wrapped;
    }
    return out;
  }

  Future<void> _applyValue(
      SharedPreferences prefs, String key, Map<String, dynamic> w) async {
    final t = w['_t'] as String?;
    final v = w['_v'];
    if (t == null || v == null) return;
    switch (t) {
      case 'b':
        await prefs.setBool(key, v as bool);
      case 'i':
        await prefs.setInt(key, (v as num).toInt());
      case 'd':
        await prefs.setDouble(key, (v as num).toDouble());
      case 's':
        await prefs.setString(key, v as String);
      case 'l':
        await prefs.setStringList(key, (v as List).cast<String>());
    }
  }

  /// Pull cloud settings and apply them, then push the local blob.
  /// Cloud wins on conflicts (any device's latest change propagates).
  Future<void> syncNow() async {
    if (_syncing) return;
    final email = SessionManager.instance.currentEmail;
    if (email == null || email.isEmpty) return;

    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Pull + apply (cloud wins)
      final loadResp = await http.post(
        Uri.parse(KoraApi.settingsSyncEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'load', 'userEmail': email}),
      ).timeout(const Duration(seconds: 15));

      if (loadResp.statusCode == 200) {
        final data = jsonDecode(loadResp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final settings = data['settings'] as Map<String, dynamic>? ?? {};
          for (final entry in settings.entries) {
            if (_isExcluded(entry.key)) continue;
            await _applyValue(
                prefs, entry.key, entry.value as Map<String, dynamic>);
          }
        }
      }

      // 2. Push the (now merged) local blob so new/changed keys reach cloud
      final blob = await _collectSyncable(prefs);
      if (blob.isNotEmpty) {
        await http.post(
          Uri.parse(KoraApi.settingsSyncEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'save',
            'userEmail': email,
            'settings': blob,
          }),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      // Best-effort — local storage remains the working copy.
    } finally {
      _syncing = false;
    }
  }

  /// Start the periodic convergence timer.
  void startPeriodicSync({Duration interval = const Duration(minutes: 10)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => syncNow());
  }

  void stopPeriodicSync() {
    _timer?.cancel();
    _timer = null;
  }
}
