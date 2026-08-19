import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Security notifications settings screen — controls which security
/// events (new logins, password changes, suspicious activity) Kora
/// alerts the user about.
class SecurityNotificationsScreen extends StatefulWidget {
  const SecurityNotificationsScreen({super.key});

  @override
  State<SecurityNotificationsScreen> createState() => _SecurityNotificationsScreenState();
}

class _SecurityNotificationsScreenState extends State<SecurityNotificationsScreen> {
  bool _newLoginAlerts = true;
  bool _passwordChanged = true;
  bool _suspiciousActivity = true;

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
          'Security Notifications',
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
                child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Stay alerted about your account',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "Choose which security events you'd like Kora to email you about.",
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 28),
            _toggleTile(
              icon: Icons.login_rounded,
              title: 'New Login Alerts',
              subtitle: 'When your account is accessed from a new device',
              value: _newLoginAlerts,
              onChanged: (v) => setState(() => _newLoginAlerts = v),
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _toggleTile(
              icon: Icons.lock_reset_rounded,
              title: 'Password Changed',
              subtitle: 'When your account password is changed',
              value: _passwordChanged,
              onChanged: (v) => setState(() => _passwordChanged = v),
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _toggleTile(
              icon: Icons.warning_amber_rounded,
              title: 'Suspicious Activity',
              subtitle: 'Unusual sign-in attempts or account behavior',
              value: _suspiciousActivity,
              onChanged: (v) => setState(() => _suspiciousActivity = v),
              card: card,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 8),
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
                      'Security notifications are sent to your registered email and cannot be fully disabled for critical account changes.',
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

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              child: Icon(icon, color: KoraColors.purple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: KoraColors.purple,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
