import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../services/crash_logger.dart';
import 'two_factor_verify_screen.dart';
import 'secure_pin_screen.dart';

/// 2FA Verification settings screen.
///
/// Toggle requires email verification to turn ON or OFF.
/// "Backup code" opens the Secure PIN creation flow.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _enabled = false;
  bool _isLoading = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final session = await SessionManager.instance.loadSession();
    if (mounted && session != null) {
      setState(() {
        _userEmail = session['email'] as String?;
        _enabled = session['twoFactorEnabled'] == true;
      });
    }
  }

  Future<void> _onToggleChanged(bool value) async {
    if (_isLoading) return;
    if (_userEmail == null || _userEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to determine your email. Please restart the app.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetEnabled = value;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TwoFactorVerifyScreen(
          email: _userEmail!,
          enabling: targetEnabled,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() => _enabled = targetEnabled);
      await _persistTwoFactor(targetEnabled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(targetEnabled
              ? 'Two-Factor Authentication is now enabled.'
              : 'Two-Factor Authentication is now disabled.'),
          backgroundColor: targetEnabled ? KoraColors.purple : const Color(0xFF6B6B80),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _persistTwoFactor(bool enabled) async {
    try {
      final session = await SessionManager.instance.loadSession();
      if (session != null) {
        session['twoFactorEnabled'] = enabled;
        await SessionManager.instance.saveSession(session);
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'TwoFactorScreen._persistTwoFactor');
    }
  }

  void _openBackupCodes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SecurePinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '2FA Verification',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add an extra layer of security',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "When enabled, you'll need to enter a verification code sent to your email every time you sign in from a new or untrusted device.",
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KoraColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: KoraColors.purple, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Two-Factor Authentication',
                            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(_enabled ? 'Enabled' : 'Disabled',
                            style: TextStyle(color: textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _enabled,
                    activeTrackColor: KoraColors.purple,
                    onChanged: _onToggleChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _openBackupCodes,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.password_rounded, color: KoraColors.purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backup code',
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('Create a secure PIN as a backup',
                              style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KoraColors.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KoraColors.purple.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: KoraColors.purple, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toggling 2FA requires email verification. A code will be sent to ${_userEmail ?? 'your email'} to confirm it\'s you.',
                      style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
