import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/kora_api.dart';
import 'session_manager.dart';

/// Telegram-style Service Notification system.
///
/// The server pushes service notifications that appear as:
/// 1. A popup alert (immediate dialog) if popup=true
/// 2. A message in the "Kora Notifications" system chat if popup=false
///
/// The client polls the backend every 30 seconds for new notifications.
/// Duplicate notifications of the same type within 15 minutes are
/// deduplicated by the backend.
class ServiceNotificationService {
  static final ServiceNotificationService instance = ServiceNotificationService._();
  ServiceNotificationService._();

  Timer? _pollTimer;
  String? _lastSeenTimestamp;
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize and start polling. Call once after login.
  void init({GlobalKey<NavigatorState>? navigatorKey}) {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    _initialized = true;
    _loadLastSeen();
    _startPolling();
  }

  /// Stop polling and clean up. Call on logout.
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
    _lastSeenTimestamp = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll immediately, then every 30 seconds
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenTimestamp = prefs.getString('kora_service_notif_last_seen');
  }

  Future<void> _saveLastSeen(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_service_notif_last_seen', timestamp);
    _lastSeenTimestamp = timestamp;
  }

  Future<void> _poll() async {
    final email = SessionManager.instance.currentEmail;
    if (email.isEmpty) return;

    try {
      final result = await KoraApi.postTo(
        KoraApi.serviceNotificationEndpoint,
        {
          'action': 'poll',
          'email': email,
          'lastSeenTimestamp': _lastSeenTimestamp,
        },
      );

      if (result['success'] == true) {
        final notifications = result['notifications'] as List? ?? [];
        if (notifications.isNotEmpty) {
          for (final notif in notifications) {
            final popup = notif['popup'] == true;
            final text = notif['text'] as String? ?? '';
            final timestamp = notif['timestamp'] as String? ?? '';
            final type = notif['type'] as String? ?? '';
            final id = notif['id'] as String? ?? '';

            if (popup) {
              _showPopupNotification(text, type);
            }

            // Mark as seen
            await _markSeen([id]);

            // Update last seen timestamp
            if (timestamp.isNotEmpty) {
              await _saveLastSeen(timestamp);
            }
          }
        }
      }
    } catch (_) {
      // Silently ignore poll errors — will retry next cycle
    }
  }

  Future<void> _markSeen(List<String> ids) async {
    final email = SessionManager.instance.currentEmail;
    if (email.isEmpty || ids.isEmpty) return;

    try {
      await KoraApi.postTo(
        KoraApi.serviceNotificationEndpoint,
        {
          'action': 'markSeen',
          'email': email,
          'notificationIds': ids,
        },
      );
    } catch (_) {}
  }

  void _showPopupNotification(String text, String type) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final brightness = Theme.of(context).brightness;
    final card = Theme.of(context).cardColor;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6C5CE7), size: 32),
        title: const Text(
          'Kora Notification',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Advance the last-seen marker so the 30s poll doesn't re-alert
  /// for notifications the user has already read. Called when the
  /// Kora Notifications chat is opened (read-on-open, like Telegram's
  /// 777000 service chat).
  Future<void> syncLastSeen({String? to}) async {
    await _saveLastSeen(to ?? DateTime.now().toIso8601String());
  }

  /// Manually fetch notification history (for the Kora Notifications chat screen).
  Future<List<Map<String, dynamic>>> getHistory({int limit = 50, int skip = 0}) async {
    final email = SessionManager.instance.currentEmail;
    if (email.isEmpty) return [];

    try {
      final result = await KoraApi.postTo(
        KoraApi.serviceNotificationEndpoint,
        {
          'action': 'history',
          'email': email,
          'limit': limit,
          'skip': skip,
        },
      );

      if (result['success'] == true) {
        final notifs = result['notifications'] as List? ?? [];
        return notifs.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    return [];
  }

  /// Mark all notifications as seen (when user opens the Kora Notifications chat).
  Future<void> markAllSeen() async {
    final email = SessionManager.instance.currentEmail;
    if (email.isEmpty) return;

    try {
      await KoraApi.postTo(
        KoraApi.serviceNotificationEndpoint,
        {
          'action': 'markSeen',
          'email': email,
          'notificationIds': [],
        },
      );
    } catch (_) {}
  }
}
