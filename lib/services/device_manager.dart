import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a unique device ID stored locally.
///
/// On first launch, generates a UUID-style ID and persists it.
/// This ID is sent to the backend so the server can recognize
/// returning devices and skip the verification code step.
///
/// When you migrate to your own backend, just change how the ID
/// is generated or stored — the interface stays the same.
class DeviceManager {
  static const _deviceIdKey = 'kora_device_id';
  static const _deviceNameKey = 'kora_device_name';

  static String? _cachedDeviceId;
  static String? _cachedDeviceName;

  /// Returns the unique device ID, generating one if it doesn't exist.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);

    if (id == null || id.isEmpty) {
      // Generate a unique ID
      id = _generateDeviceId();
      await prefs.setString(_deviceIdKey, id);
    }

    _cachedDeviceId = id;
    return id;
  }

  /// Returns a human-readable device name (e.g., "Android 14" or "iOS 17").
  static Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;

    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString(_deviceNameKey);

    if (name == null || name.isEmpty) {
      name = _detectDeviceName();
      await prefs.setString(_deviceNameKey, name);
    }

    _cachedDeviceName = name;
    return name;
  }

  /// Returns the current platform name.
  static String getPlatform() {
    return Platform.operatingSystem; // 'android' or 'ios'
  }

  /// Generates a unique device ID using timestamp + random components.
  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final platform = Platform.operatingSystem;
    return 'dev-${platform}-${timestamp}-${random.toString().substring(random.toString().length - 6)}';
  }

  /// Detects a readable device name from platform info.
  static String _detectDeviceName() {
    final os = Platform.operatingSystem;
    if (Platform.isAndroid) {
      return 'Android Device';
    } else if (Platform.isIOS) {
      return 'iOS Device';
    }
    return os[0].toUpperCase() + os.substring(1);
  }
}
