import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kora's Firebase Messaging service.
///
/// Handles FCM token registration, background message handling,
/// and bridges between the native notification system and Flutter.
///
/// Modeled after WhatsApp's push architecture:
/// - Token registration on app start
/// - Background message handler (runs even when app is killed)
/// - Topic subscriptions for broadcast notifications
/// - Token refresh handling
class KoraFirebaseService {
  static final KoraFirebaseService instance = KoraFirebaseService._();
  KoraFirebaseService._();

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _initialized = false;

  // Callback for when a token is received/refreshed
  void Function(String token)? onTokenReceived;

  // Callback for when a data message is received while app is in foreground
  void Function(Map<String, dynamic> data)? onForegroundMessage;

  /// Initialize Firebase and FCM.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      // Request permission (Android 13+)
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
      );

      // Get FCM token
      _fcmToken = await _messaging!.getToken();
      if (_fcmToken != null) {
        debugPrint('[KoraFCM] Token: ${_fcmToken!.substring(0, 20)}...');
        onTokenReceived?.call(_fcmToken!);

        // Store token for native side to read
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        debugPrint('[KoraFCM] Token refreshed');
        _fcmToken = newToken;
        onTokenReceived?.call(newToken);
      });

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[KoraFCM] Foreground message: ${message.data}');
        onForegroundMessage?.call(message.data);
      });

      // Listen for notification taps (when app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[KoraFCM] Notification tapped: ${message.data}');
        _handleNotificationTap(message.data);
      });

      // Check for initial notification (app opened from notification)
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[KoraFCM] Initial notification: ${initialMessage.data}');
        _handleNotificationTap(initialMessage.data);
      }

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_koraBackgroundMessageHandler);

      _initialized = true;
      debugPrint('[KoraFCM] Firebase Messaging initialized');
    } catch (e) {
      debugPrint('[KoraFCM] Init error: $e');
    }
  }

  /// Get the current FCM token.
  String? get fcmToken => _fcmToken;

  /// Subscribe to a topic (e.g., for broadcast notifications).
  Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
    debugPrint('[KoraFCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging?.unsubscribeFromTopic(topic);
  }

  /// Subscribe to the "all" topic for global announcements.
  Future<void> subscribeToGlobalTopic() async {
    await subscribeToTopic('kora_all');
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Route to the notification service
    final chatId = data['chat_id'] as String?;
    KoraNotificationService.instance.onNotificationTapped?.call(chatId);
  }

  /// Background message handler — runs even when app is killed.
  /// Must be top-level function (not a class method).
  static Future<void> _koraBackgroundMessageHandler(RemoteMessage message) async {
    debugPrint('[KoraFCM] Background message: ${message.data['type']}');

    // Ensure Firebase is initialized in background isolate
    await Firebase.initializeApp();

    // The native FCM service (KoraFcmService) handles the actual notification display.
    // This handler is for any additional background processing.
    // On Android, if the message has a 'data' payload, the native service handles it.

    // Persist for Flutter to process on next startup
    final prefs = await SharedPreferences.getInstance();
    final data = message.data;
    prefs.setString('last_bg_notif_type', data['type'] ?? 'unknown');
    prefs.setString('last_bg_notif_chat', data['chat_id'] ?? '');
    prefs.setInt('last_bg_notif_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
}
