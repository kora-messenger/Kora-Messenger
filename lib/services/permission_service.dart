import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central permission manager for Kora Messenger.
///
/// Requests exactly the permissions Kora needs, when they're needed —
/// not all at once on cold launch (which feels invasive). The one
/// exception is [requestEssentialOnce], fired the first time a user
/// reaches the Home screen after signing in, which asks for
/// Notifications + Microphone + Camera + Gallery up front (like
/// WhatsApp/Telegram do on first run) so the rest of the app just works.
class KoraPermissionService {
  static const _kEssentialAsked = 'kora_essential_permissions_asked';

  /// Requests Notifications, Microphone, Camera, and Gallery/Photos
  /// once per install — right after the user reaches Home for the
  /// first time. Safe to call every time; it no-ops after the first run.
  static Future<void> requestEssentialOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kEssentialAsked) ?? false;
    if (alreadyAsked) return;

    await [
      Permission.notification,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
    ].request();

    await prefs.setBool(_kEssentialAsked, true);
  }

  /// Microphone — required before recording a voice message or
  /// starting any voice/video call.
  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Camera — required before opening the camera (profile photo,
  /// group photo, wallpaper photo, video calls).
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Gallery/Photos — required before picking an image from the
  /// device's gallery.
  static Future<bool> requestGallery() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Notifications — required to show message/call push alerts.
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// True if the permission was permanently denied (user must enable
  /// it from system Settings). Callers should show an "Open Settings"
  /// prompt in this case rather than requesting again.
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    return permission.status.then((s) => s.isPermanentlyDenied);
  }

  static Future<void> openSettings() => openAppSettings();
}
