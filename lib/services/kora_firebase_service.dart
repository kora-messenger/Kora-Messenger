import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/kora_api.dart';
import 'notification_service.dart';

/// Background message handler — must be top-level function.
/// Called by FCM when a message arrives and the app is in background/killed.
@pragma('vm:entry-point')
Future<void> koraFcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('[KoraFCM] Background message: ${message.data}');
  // Notification is built by native KoraFcmService.kt (Kotlin side).
  // This Dart handler runs for data-only processing if needed.
}

/// Kora Firebase Cloud Messaging service.
///
/// Handles:
/// - Firebase initialization
/// - FCM token acquisition + refresh
/// - Token registration with Kora backend
/// - Foreground message handling
/// - Notification permission requests
///
/// Safe to call even without google-services.json — silently disables
/// push notifications if Firebase isn't configured.
class KoraFirebaseService {
  static final KoraFirebaseService instance = KoraFirebaseService._();
  KoraFirebaseService._();

  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _fcmToken;

  // SharedPreferences keys (shared with native Kotlin KoraFcmService.kt)
  static const _kTokenKey = 'kora_fcm_token';
  static const _kTokenTsKey = 'kora_fcm_token_ts';

  /// Initialize Firebase and FCM.
  /// Returns true if push notifications are active, false if disabled.
  Future<bool> init() async {
    if (_initialized) return _firebaseAvailable;

    try {
      // Try to initialize Firebase — fails gracefully if no google-services.json
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      debugPrint('[KoraFCM] Firebase initialized ✅');
    } catch (e) {
      debugPrint('[KoraFCM] Firebase not configured — push disabled. '
          'Add google-services.json to enable FCM. Error: $e');
      _initialized = true;
      _firebaseAvailable = false;
      return false;
    }

    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(koraFcmBackgroundHandler);

      // Request notification permission (Android 13+ auto-grants, but call anyway)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('[KoraFCM] Permission: ${settings.authorizationStatus}');

      // Get FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      if (_fcmToken != null) {
        debugPrint('[KoraFCM] Token: ${_fcmToken!.substring(0, 20)}...');
        await registerTokenWithBackend();
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[KoraFCM] Token refreshed: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        registerTokenWithBackend();
      });

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[KoraFCM] Foreground message from: ${message.senderId}');
        // Native Kotlin KoraFcmService handles notification building.
        // On Android, foreground FCM messages go to the Dart side,
        // so we trigger local notification display here.
        _handleForegroundMessage(message);
      });

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[KoraFCM] Setup error: $e');
      _initialized = true;
      _firebaseAvailable = false;
      return false;
    }
  }

  /// Handle a foreground FCM message — show a local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] ?? 'message';
      final senderName = data['sender_name'] ?? data['name'] ?? 'Kora';
      final messageText = data['message'] ?? data['body'] ?? data['text'] ?? '';
      final chatId = data['chat_id'] ?? data['jid'] ?? '';

      if (messageText.isEmpty) return;

      // Use the existing notification service to show the notification
      _showForegroundNotification(
        type: type,
        senderName: senderName,
        messageText: messageText,
        chatId: chatId,
      );
    } catch (e) {
      debugPrint('[KoraFCM] Foreground handler error: $e');
    }
  }

  void _showForegroundNotification({
    required String type,
    required String senderName,
    required String messageText,
    required String chatId,
  }) {
    try {
      KoraNotificationService.instance.showMessageNotification(
        senderName: senderName,
        message: messageText,
        chatId: chatId,
        isGroup: type == 'group_message',
      );
    } catch (e) {
      debugPrint('[KoraFCM] Show notification error: $e');
    }
  }

  /// Register the FCM token with the Kora backend.
  Future<void> registerTokenWithBackend() async {
    if (_fcmToken == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');
      if (userEmail == null || userEmail.isEmpty) return;

      final response = await http.post(
        Uri.parse(KoraApi.pushRegisterEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'fcmToken': _fcmToken,
          'platform': Platform.operatingSystem,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[KoraFCM] Token registered with backend ✅');
      } else {
        debugPrint('[KoraFCM] Token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KoraFCM] Token registration error: $e');
    }
  }

  /// Check if native Kotlin side has a newer token (from KoraFcmService.kt onNewToken).
  Future<void> syncNativeToken() async {
    if (!_firebaseAvailable) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final nativeToken = prefs.getString(_kTokenKey);
      if (nativeToken != null && nativeToken.isNotEmpty && nativeToken != _fcmToken) {
        debugPrint('[KoraFCM] Found newer native token, updating');
        _fcmToken = nativeToken;
        await registerTokenWithBackend();
      }
    } catch (e) {
      debugPrint('[KoraFCM] Native token sync error: $e');
    }
  }

  /// Unregister the FCM token (on logout).
  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');
      if (userEmail == null) return;

      await http.post(
        Uri.parse(KoraApi.pushUnregisterEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'fcmToken': _fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));

      // Delete the FCM token from Firebase
      if (_firebaseAvailable) {
        await FirebaseMessaging.instance.deleteToken();
      }

      _fcmToken = null;
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kTokenTsKey);

      debugPrint('[KoraFCM] Token unregistered ✅');
    } catch (e) {
      debugPrint('[KoraFCM] Unregister error: $e');
    }
  }

  /// Get current FCM token (null if not available).
  String? get token => _fcmToken;

  /// Whether Firebase push is active.
  bool get isAvailable => _firebaseAvailable;
}
