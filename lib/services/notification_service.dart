import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Kora's local notification service.
///
/// Creates notification channels and displays message/call notifications
/// with the app's icon showing in the system notification bar/center.
/// Uses a custom monochrome icon (`kora_notification_icon`) so the icon
/// renders correctly on all Android versions (8.0+ requires a white
/// silhouette icon that the system tints).
class KoraNotificationService {
  static final KoraNotificationService instance = KoraNotificationService._();
  KoraNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const _kMessageChannel = 'kora_messages';
  static const _kCallChannel = 'kora_calls';
  static const _kGeneralChannel = 'kora_general';

  bool _initialized = false;

  /// Initializes notification channels and the plugin. Call once
  /// early in app startup (e.g. in main()).
  Future<void> init() async {
    if (_initialized) return;

    // Android init with our custom notification icon
    const androidInit = AndroidInitializationSettings('@drawable/kora_notification_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android 8.0+
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createChannels();
    }

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Messages channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kMessageChannel,
        'Messages',
        description: 'New message notifications',
        importance: Importance.high,
        enableVibration: true,
        enableLights: true,
        playSound: true,
      ),
    );

    // Calls channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kCallChannel,
        'Calls',
        description: 'Incoming and missed call notifications',
        importance: Importance.high,
        enableVibration: true,
        enableLights: true,
        playSound: true,
      ),
    );

    // General channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kGeneralChannel,
        'General',
        description: 'General Kora notifications',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Shows a new message notification.
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    String? chatId,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _kMessageChannel,
      'Messages',
      channelDescription: 'New message notifications',
      icon: '@drawable/kora_notification_icon',
      priority: Priority.high,
      importance: Importance.high,
      category: AndroidNotificationCategory.message,
      enableVibration: true,
      enableLights: true,
      styleInformation: MessagingStyleInformation(
        Person(name: senderName, key: chatId),
        conversationTitle: senderName,
        messages: [
          Message(
            message,
            DateTime.now(),
            Person(name: senderName, key: chatId),
          ),
        ],
      ),
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    // Use a hash of the chatId as the notification ID so each chat
    // gets its own notification slot.
    final notifId = chatId?.hashCode ?? senderName.hashCode;

    await _plugin.show(
      notifId,
      senderName,
      message,
      notifDetails,
      payload: chatId,
    );
  }

  /// Shows an incoming call notification (high priority, full screen).
  Future<void> showCallNotification({
    required String callerName,
    bool isVideo = false,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _kCallChannel,
      'Calls',
      channelDescription: 'Incoming and missed call notifications',
      icon: '@drawable/kora_notification_icon',
      priority: Priority.max,
      importance: Importance.max,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      fullScreenIntent: true,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9999, // fixed ID for call notifications
      isVideo ? 'Incoming video call' : 'Incoming voice call',
      callerName,
      notifDetails,
    );
  }

  /// Shows a missed call notification.
  Future<void> showMissedCallNotification({
    required String callerName,
    bool isVideo = false,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _kCallChannel,
      'Calls',
      channelDescription: 'Incoming and missed call notifications',
      icon: '@drawable/kora_notification_icon',
      priority: Priority.high,
      importance: Importance.high,
      category: AndroidNotificationCategory.call,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9998, // fixed ID for missed call notifications
      isVideo ? 'Missed video call' : 'Missed voice call',
      callerName,
      notifDetails,
    );
  }

  /// Cancels a specific notification by ID.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: payload=${response.payload}');
    // TODO: Navigate to the relevant chat when the app is opened
    // from a notification. This will be wired up when deep-linking
    // is implemented.
  }
}
