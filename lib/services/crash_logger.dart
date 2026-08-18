import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures and persists every uncaught error in Kora Messenger.
///
/// Three error sources are wired up in [main]:
/// 1. `FlutterError.onError` — widget build / framework errors
/// 2. `Isolate.current.addErrorListener` — errors in other isolates
/// 3. `runZonedGuarded` — any uncaught async/sync error in the root zone
///
/// Each crash record contains:
/// - timestamp, error type, message, stack trace
/// - app version, platform, isDebug
///
/// Logs are stored in SharedPreferences as a JSON array (max 100 entries).
/// When you migrate to your own backend, add an upload step in [log].
class CrashLogger {
  static const _storageKey = 'kora_crash_logs';
  static const _maxEntries = 100;

  /// App version — update on each release. Domain-swappable.
  static const String appVersion = '1.0.0';

  /// Call once at app startup (before runApp, inside runZonedGuarded).
  static void init() {
    // 1. Flutter framework errors (build failures, layout errors, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      _record(
        type: 'FlutterError',
        message: details.exceptionAsString(),
        stackTrace: details.stack?.toString() ?? '(no stack trace)',
      );
      FlutterError.presentError(details);
    };

    // 2. Isolate errors (errors thrown in other Dart isolates)
    Isolate.current.addErrorListener(RawReceivePort((dynamic pair) {
      final List<dynamic> errorData = pair as List<dynamic>;
      _record(
        type: 'IsolateError',
        message: errorData[0].toString(),
        stackTrace: errorData[1].toString(),
      );
    }).sendPort);
  }

  /// Manually log a caught exception (useful in try-catch blocks).
  static Future<void> log(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
  }) async {
    await _record(
      type: 'CaughtError${context != null ? ' ($context)' : ''}',
      message: exception.toString(),
      stackTrace: stackTrace?.toString() ?? '(no stack trace)',
    );
  }

  /// Core method — writes a crash entry to local storage.
  static Future<void> _record({
    required String type,
    required String message,
    required String stackTrace,
  }) async {
    try {
      final entry = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'message': message,
        'stackTrace': stackTrace,
        'appVersion': appVersion,
        'platform': Platform.operatingSystem,
        'isDebug': kDebugMode.toString(),
      };

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final List<dynamic> logs = raw != null ? jsonDecode(raw) as List<dynamic> : [];

      logs.insert(0, entry);

      if (logs.length > _maxEntries) {
        logs.removeRange(_maxEntries, logs.length);
      }

      await prefs.setString(_storageKey, jsonEncode(logs));
    } catch (e) {
      debugPrint('[CrashLogger] Failed to store crash log: $e');
    }
  }

  /// Read all stored crash logs (newest first).
  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final List<dynamic> logs = jsonDecode(raw) as List<dynamic>;
    return logs.cast<Map<String, dynamic>>();
  }

  /// Delete all stored crash logs.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Get the count of stored crash logs.
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return 0;
    return (jsonDecode(raw) as List<dynamic>).length;
  }
}
