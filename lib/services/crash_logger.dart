import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/kora_api.dart';

/// Captures and persists every uncaught error in Kora Messenger.
///
/// Three error sources are wired up in [main]:
/// 1. `FlutterError.onError` — widget build / framework errors
/// 2. `Isolate.current.addErrorListener` — errors in other isolates
/// 3. `runZonedGuarded` — any uncaught async/sync error in the root zone
///
/// Fatal (uncaught) crashes set a flag so the next launch shows the
/// CrashReportScreen with a copiable/downloadable log.
///
/// Logs are stored locally in SharedPreferences (max 100 entries)
/// AND uploaded to the backend, which creates a GitHub Issue automatically.
/// Domain-swappable: just change [KoraApi.crashReportEndpoint].
class CrashLogger {
  static const _storageKey = 'kora_crash_logs';
  static const _unreadCrashKey = 'kora_has_unread_crash';
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
        isFatal: true,
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
        isFatal: true,
      );
    }).sendPort);
  }

  /// Manually log a caught exception (useful in try-catch blocks).
  /// These are NOT fatal and won't trigger the crash report screen.
  static Future<void> log(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
    bool isFatal = false,
  }) async {
    await _record(
      type: 'CaughtError${context != null ? ' ($context)' : ''}',
      message: exception.toString(),
      stackTrace: stackTrace?.toString() ?? '(no stack trace)',
      isFatal: isFatal,
    );
  }

  /// Core method — stores crash locally AND uploads to backend (GitHub Issue).
  static Future<void> _record({
    required String type,
    required String message,
    required String stackTrace,
    required bool isFatal,
  }) async {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'message': message,
      'stackTrace': stackTrace,
      'appVersion': appVersion,
      'platform': Platform.operatingSystem,
      'isDebug': kDebugMode.toString(),
      'isFatal': isFatal.toString(),
      'uploaded': 'false',
    };

    // 1. Store locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final List<dynamic> logs = raw != null ? jsonDecode(raw) as List<dynamic> : [];

      logs.insert(0, entry);

      if (logs.length > _maxEntries) {
        logs.removeRange(_maxEntries, logs.length);
      }

      await prefs.setString(_storageKey, jsonEncode(logs));

      // Set the unread crash flag if this was a fatal crash.
      if (isFatal) {
        await prefs.setBool(_unreadCrashKey, true);
      }
    } catch (e) {
      debugPrint('[CrashLogger] Failed to store crash log locally: $e');
    }

    // 2. Upload to backend (creates GitHub Issue)
    // Always attempt upload — even in debug mode — so we never lose a crash.
    // The backend deduplicates by message, so debug spam isn't an issue.
    try {
      final response = await http.post(
        Uri.parse(KoraApi.crashReportEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': entry['type'],
          'message': entry['message'],
          'stackTrace': entry['stackTrace'],
          'appVersion': entry['appVersion'],
          'platform': entry['platform'],
          'timestamp': entry['timestamp'],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[CrashLogger] Crash report uploaded -> GitHub Issue created');
        // Mark as uploaded locally
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_storageKey);
          if (raw != null) {
            final List<dynamic> logs = jsonDecode(raw) as List<dynamic>;
            if (logs.isNotEmpty) {
              logs[0]['uploaded'] = 'true';
              await prefs.setString(_storageKey, jsonEncode(logs));
            }
          }
        } catch (_) {}
      } else {
        debugPrint('[CrashLogger] Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CrashLogger] Upload error: $e');
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

  /// Get the most recent fatal crash log (for the crash report screen).
  /// Returns null if there's no unread fatal crash.
  static Future<Map<String, dynamic>?> getUnreadCrash() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUnread = prefs.getBool(_unreadCrashKey) ?? false;
    if (!hasUnread) return null;

    final logs = await getAll();
    if (logs.isEmpty) return null;

    // Find the most recent fatal crash.
    for (final log in logs) {
      if (log['isFatal'] == 'true') {
        return log;
      }
    }

    // Fallback — if no fatal flag, just return the most recent.
    return logs.first;
  }

  /// Clear the unread crash flag (call after the user has seen the crash report).
  static Future<void> clearUnreadCrash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unreadCrashKey, false);
  }

  /// Check if there's an unread fatal crash (for splash screen routing).
  static Future<bool> hasUnreadCrash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unreadCrashKey) ?? false;
  }

  /// Delete all stored crash logs.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.setBool(_unreadCrashKey, false);
  }

  /// Get the count of stored crash logs.
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return 0;
    return (jsonDecode(raw) as List<dynamic>).length;
  }

  /// Format a crash log entry into a readable text string for copying/downloading.
  static String formatCrashLog(Map<String, dynamic> log) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('  KORA MESSENGER — CRASH REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Timestamp:  ${log['timestamp'] ?? 'unknown'}');
    buffer.writeln('Type:       ${log['type'] ?? 'Unknown'}');
    buffer.writeln('Platform:   ${log['platform'] ?? 'unknown'}');
    buffer.writeln('App Version: ${log['appVersion'] ?? 'unknown'}');
    buffer.writeln('Debug Mode: ${log['isDebug'] ?? 'unknown'}');
    buffer.writeln('Uploaded:   ${log['uploaded'] ?? 'unknown'}');
    buffer.writeln('');
    buffer.writeln('─── Error Message ────────────────────────────────────────');
    buffer.writeln('');
    buffer.writeln(log['message'] ?? '(no message)');
    buffer.writeln('');
    buffer.writeln('─── Stack Trace ──────────────────────────────────────────');
    buffer.writeln('');
    buffer.writeln(log['stackTrace'] ?? '(no stack trace)');
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    return buffer.toString();
  }
}
