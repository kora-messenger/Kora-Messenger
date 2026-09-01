import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Wraps a screen to prevent screenshots and screen recording on
/// Android via FLAG_SECURE. On iOS it prevents screen recording
/// via a native approach (future). When the widget is disposed,
/// the secure flag is cleared so other screens aren't affected.
///
/// Usage: wrap any sensitive screen (e.g. contact profile) with
/// `SecureScreen(child: ...)`. The flag is set on initState and
/// cleared on dispose.
class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static const _channel = MethodChannel('com.kora.messenger/secure');

  @override
  void initState() {
    super.initState();
    _enableSecure();
  }

  @override
  void dispose() {
    _disableSecure();
    super.dispose();
  }

  Future<void> _enableSecure() async {
    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // Silently fail on non-Android platforms or if not available
    }
  }

  Future<void> _disableSecure() async {
    try {
    if (kIsWeb) {
      // Web fallback: skip native channel call
      return;
    }

      await _channel.invokeMethod('disableSecure');
    } catch (_) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
