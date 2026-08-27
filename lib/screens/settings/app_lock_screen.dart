import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

/// App lock settings screen allowing biometric authentication toggle
/// and auto-lock timeout preferences.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const String _key = 'app_lock_enabled';
  static const String _privacyKey = 'kora_privacy_app_lock';
  static const String _timeoutKey = 'app_lock_timeout';

  bool _enabled = false;
  String _timeout = 'Immediately';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_key) ?? prefs.getBool(_privacyKey) ?? false;
      _timeout = prefs.getString(_timeoutKey) ?? 'Immediately';
      _isLoading = false;
    });
  }

  Future<void> _toggleLock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
    await prefs.setBool(_privacyKey, val);
    setState(() {
      _enabled = val;
    });
  }

  Future<void> _setTimeout(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeoutKey, val);
    setState(() {
      _timeout = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'App lock',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: KoraColors.purple))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: KoraColors.purple, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlock with biometrics',
                              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When enabled, you\'ll need to use Face ID or fingerprint to open Kora. You can still answer calls if Kora is locked.',
                              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        activeTrackColor: KoraColors.purple,
                        onChanged: _toggleLock,
                      ),
                    ],
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Automatically lock',
                      style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: ['Immediately', 'After 1 minute', 'After 15 minutes', 'After 1 hour'].map((opt) {
                        final isSelected = opt == _timeout;
                        return ListTile(
                          onTap: () => _setTimeout(opt),
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? KoraColors.purple : textSecondary,
                            size: 22,
                          ),
                          title: Text(
                            opt,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: KoraColors.purple, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Biometric prompt will be displayed whenever Kora requires authentication.',
                            style: TextStyle(color: textPrimary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
