import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Passkeys settings screen — passwordless sign-in using the device's
/// biometrics (Face ID / fingerprint) or PIN, instead of a password.
class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key});

  @override
  State<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends State<PasskeysScreen> {
  bool _enabled = false;

  void _addPasskey() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adding a passkey is coming soon.'),
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
          'Passkeys',
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
                child: const Icon(Icons.key_rounded, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in without a password',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Use Face ID, your fingerprint, or your device PIN to sign in to Kora instantly and securely — no password needed.',
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
                    child: const Icon(Icons.key_rounded, color: KoraColors.purple, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Use Passkeys',
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
            const SizedBox(height: 20),
            if (_enabled) ...[
              Text(
                'YOUR PASSKEYS',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.fingerprint, color: textMuted, size: 28),
                    const SizedBox(height: 10),
                    Text('No passkeys added yet',
                        style: TextStyle(color: textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _addPasskey,
                  style: TextButton.styleFrom(
                    foregroundColor: KoraColors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: KoraColors.purple, width: 1),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Add a Passkey', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
                      'Passkeys are stored securely on your device and never leave it. Your password still works as a backup sign-in method.',
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
