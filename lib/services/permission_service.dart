import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central permission manager for Kora Messenger.
///
/// Requests exactly the permissions Kora needs, when they're needed.
/// On first launch after sign-in, [requestEssentialOnce] asks for all
/// essential permissions at once (like WhatsApp/Telegram do) so the
/// rest of the app just works.
///
/// Permissions Kora needs:
/// - Notifications: message & call push alerts
/// - Microphone: voice messages, voice/video calls
/// - Camera: photos, video calls, QR scanning
/// - Gallery/Photos: picking images to send
/// - Storage (Android <13): saving received media
/// - Location: sharing live location in chats
/// - Contacts: finding friends already on Kora
/// - Phone state: handling in-call interruptions
class KoraPermissionService {
  static const _kEssentialAsked = 'kora_essential_permissions_asked';

  /// Requests all essential permissions once per install — right
  /// after the user reaches Home for the first time. Safe to call
  /// every time; it no-ops after the first run.
  static Future<void> requestEssentialOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kEssentialAsked) ?? false;
    if (alreadyAsked) return;

    // Request all permissions Kora needs
    await [
      Permission.notification,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.storage,       // Android <13 — for saving media
      Permission.location,      // For sharing location in chats
      Permission.contacts,      // For finding friends on Kora
      Permission.phone,         // For call state handling
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
  /// group photo, QR scan, video calls).
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Gallery/Photos — required before picking an image from the
  /// device's gallery.
  static Future<bool> requestGallery() async {
    // On Android 13+, use photos permission. On older, use storage.
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return true;
    // Fall back to storage for older Android
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Notifications — required to show message/call push alerts.
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Location — required before sharing live location in a chat.
  static Future<bool> requestLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Contacts — required to find which contacts are already on Kora.
  static Future<bool> requestContacts() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Phone state — for handling in-call interruptions during
  /// voice/video calls.
  static Future<bool> requestPhone() async {
    final status = await Permission.phone.request();
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
