import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/kora_colors.dart';
import '../../config/kora_api.dart';

/// About Kora screen — app version, terms, privacy, description.
class AboutKoraScreen extends StatelessWidget {
  const AboutKoraScreen({super.key});

  static const String _version = '1.0.0';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'About Kora',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          // Logo
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Kora Messenger',
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version $_version',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Text(
              'Kora Messenger is a premium messaging app for seamless communication. '
              'Chat with friends and family, use AI assistance, translate messages in real-time, '
              'and enjoy premium features like custom themes, app icons, and more.',
              style: TextStyle(color: textSecondary, fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),

          // Legal links
          _sectionLabel('LEGAL', textMuted),
          _linkTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => _launchUrl(KoraApi.termsOfServiceUrl),
          ),
          _linkTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => _launchUrl(KoraApi.privacyPolicyUrl),
          ),
          _linkTile(
            context,
            icon: Icons.groups_outlined,
            title: 'Community Guidelines',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => _launchUrl(KoraApi.communityGuidelinesUrl),
          ),
          _linkTile(
            context,
            icon: Icons.smart_toy_outlined,
            title: 'AI Policy',
            card: card,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            border: border,
            onTap: () => _launchUrl(KoraApi.aiPolicyUrl),
          ),
          const SizedBox(height: 20),

          // Credits
          _sectionLabel('CREDITS', textMuted),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built by Ijezie Goodluck',
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 Kora Messenger. All rights reserved.',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
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
                  color: KoraColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: KoraColors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.open_in_new, color: textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
