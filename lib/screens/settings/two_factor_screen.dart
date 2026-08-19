import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Two-factor authentication settings screen — adds an extra email
/// verification step when signing in from a new or untrusted device.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _enabled = false;

  void _viewBackupCodes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup codes are coming soon.'),
        backgroundColor: KoraColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
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
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _viewBackupCodes,
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
                          Text('Backup Codes',
                              style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('Use if you lose access to your email',
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
                      'Your account already sends a verification code for logins on new devices. Enabling 2FA here extends that protection to every sign-in.',
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
