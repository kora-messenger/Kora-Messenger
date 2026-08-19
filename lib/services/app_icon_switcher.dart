import 'package:flutter/services.dart';

/// Helper to switch the Android app icon via platform channel.
///
/// Requires activity aliases in AndroidManifest.xml — each alias
/// has its own icon resource and LAUNCHER intent-filter. Only one
/// alias is enabled at a time.
class AppIconSwitcher {
  static const _channel = MethodChannel('com.kora.messenger/icon');

  /// The 3 alias names — must match AndroidManifest.xml activity-alias names.
  /// Index 0 (IconClassic) is the free Default icon; the rest are Premium.
  static const List<String> aliases = [
    'IconClassic', 'IconAuroraCircle', 'IconGoldElite',
  ];

  /// Switches the app icon to the alias at [index].
  /// Returns true on success, false on failure.
  static Future<bool> setIcon(int index) async {
    if (index < 0 || index >= aliases.length) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setIcon', {
        'alias': aliases[index],
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
