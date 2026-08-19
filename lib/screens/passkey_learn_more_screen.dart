import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// "Learn more" info screen — explains how Passkeys work, how to
/// create one, and how they're secured on the device.
class PasskeyLearnMoreScreen extends StatelessWidget {
  const PasskeyLearnMoreScreen({super.key});

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
          'About Passkeys',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.key_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How Passkeys work',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'A Passkey is a cryptographic key stored securely on your device. '
              'When you sign in to Kora, your device uses your fingerprint, '
              'Face ID, or device PIN to authorize the sign-in — without sending '
              'your password or biometric data to any server.',
              style: TextStyle(color: textSecondary, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 28),

            // ── How to create ──
            Text(
              'How to create a Passkey',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _stepCard(card, border, textPrimary, textSecondary, '1', 'Go to Settings → Passkeys'),
            _stepCard(card, border, textPrimary, textSecondary, '2', 'Toggle "Use Passkeys" on'),
            _stepCard(card, border, textPrimary, textSecondary, '3', 'Tap "Add a Passkey"'),
            _stepCard(card, border, textPrimary, textSecondary, '4',
                'Authenticate with your fingerprint, Face ID, or device PIN when prompted'),
            _stepCard(card, border, textPrimary, textSecondary, '5',
                'Your device is now registered as a Passkey for this account'),

            const SizedBox(height: 28),

            // ── How they're secured ──
            Text(
              'How Passkeys are secured',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _bulletPoint(textSecondary, 'Passkeys never leave your device. Your biometric data is never sent to Kora\'s servers.'),
            _bulletPoint(textSecondary, 'Each Passkey is unique to the device it was created on. To sign in on a new device, you\'ll need to create a new Passkey on that device.'),
            _bulletPoint(textSecondary, 'Your password still works as a backup sign-in method. If you lose your device, you can always sign in with your email and password.'),
            _bulletPoint(textSecondary, 'You can delete a Passkey at any time from the Passkeys settings screen.'),
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
                      'Passkeys use industry-standard WebAuthn / FIDO2 technology, the same security standard used by Google, Apple, and Microsoft.',
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

  Widget _stepCard(Color card, Color border, Color textPrimary, Color textSecondary, String num, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(desc, style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(Color textSecondary, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: KoraColors.purple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
