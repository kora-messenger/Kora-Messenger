import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';

/// Manages a unique device ID that persists across app reinstalls.
///
/// Uses the OS-level persistent identifier:
/// - Android: Settings.Secure.ANDROID_ID (64-bit hex string, survives reinstall)
/// - iOS: identifierForVendor (UUID, survives reinstall)
///
/// This ensures that when a user deletes and reinstalls Kora on the same
/// physical device, the backend still recognizes the device and skips
/// the new-device verification flow. Only a truly new device triggers
/// verification.
class DeviceManager {
  static const _deviceIdKey = 'kora_device_id';
  static const _deviceNameKey = 'kora_device_name';

  static String? _cachedDeviceId;
  static String? _cachedDeviceName;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns the persistent device ID.
  /// Generates one on first launch using the OS-level identifier,
  /// then caches it in SharedPreferences as a fallback.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();

    // 1. Try to get the OS-level persistent ID (survives app reinstall)
    String? osId;
    try {
      if (Platform.isAndroid) {
        // Settings.Secure.ANDROID_ID — persists across app reinstalls.
        // device_info_plus dropped this getter after v4.0.0 (Google policy),
        // so we use the dedicated android_id plugin instead.
        osId = await const AndroidId().getId();
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor — persists across app reinstalls
        osId = iosInfo.identifierForVendor;
      }
    } catch (_) {
      // If the platform plugin fails, fall back to SharedPreferences
    }

    String deviceId;

    if (osId != null && osId.isNotEmpty) {
      // Use the persistent OS-level ID with a prefix so the backend
      // can distinguish it from legacy random IDs.
      deviceId = 'os-${Platform.operatingSystem}-$osId';
    } else {
      // Fallback: check SharedPreferences for a previously generated ID
      deviceId = prefs.getString(_deviceIdKey) ?? '';
      if (deviceId.isEmpty) {
        // Last resort: generate a random ID (won't survive reinstall,
        // but this should rarely happen)
        deviceId = _generateDeviceId();
      }
    }

    // Cache in SharedPreferences and memory
    await prefs.setString(_deviceIdKey, deviceId);
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Returns a human-readable device name (e.g., "Android 14" or "iOS 17").
  static Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;

    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString(_deviceNameKey);

    if (name == null || name.isEmpty) {
      name = await _detectDeviceName();
      await prefs.setString(_deviceNameKey, name);
    }

    _cachedDeviceName = name;
    return name;
  }

  /// Returns the current platform name.
  static String getPlatform() {
    return Platform.operatingSystem; // 'android' or 'ios'
  }

  /// Generates a fallback device ID (random — won't survive reinstall).
  static String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final platform = Platform.operatingSystem;
    final randomStr = random.toString();
    final shortId = randomStr.substring(randomStr.length - 6);
    return 'dev-$platform-$timestamp-$shortId';
  }

  /// Detects a readable device name using device_info_plus.
  static Future<String> _detectDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.utsname.machine ?? 'iOS Device';
      }
    } catch (_) {
      // Fall through to generic name
    }
    return Platform.isAndroid ? 'Android Device' : 'iOS Device';
  }
}
