import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/kora_colors.dart';
import '../ai/kora_support_screen.dart';

/// Kora Help Center — central customer care hub.
///
/// Provides structured self-help, AI support, bug reporting, and
/// direct email contact. Accessible from Profile → Help Center.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launchUrl(String url) async {
    debugPrint('[HelpCenter] _launchUrl called: $url');
    final uri = Uri.parse(url);
    debugPrint('[HelpCenter] Parsed URI: $uri');
    final canLaunch = await canLaunchUrl(uri);
    debugPrint('[HelpCenter] canLaunchUrl($uri) => $canLaunch');
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('[HelpCenter] launchUrl succeeded for: $url');
    } else {
      debugPrint('[HelpCenter] ⚠️ launchUrl FAILED — cannot launch: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HelpCenter] build() — HelpCenterScreen rendered');
    final brightness = Theme.of(context).brightness;
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
          'Help Center',
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Quick Help ──
          _sectionLabel('GET HELP', textMuted),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.support_agent_rounded,
            iconColor: KoraColors.purple,
            title: 'Kora Support',
            subtitle: 'Chat with Kora AI for instant troubleshooting',
            onTap: () { debugPrint('[HelpCenter] Tapped: Kora Support'); Navigator.push(context,
              MaterialPageRoute(builder: (_) => const KoraSupportScreen())); },
          ),
          const SizedBox(height: 8),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.bug_report_outlined,
            iconColor: const Color(0xFFEF4444),
            title: 'Report a bug',
            subtitle: 'Tell us what went wrong',
            onTap: () { debugPrint('[HelpCenter] Tapped: Report a bug'); Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ReportBugScreen())); },
          ),
          const SizedBox(height: 8),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.feedback_outlined,
            iconColor: KoraColors.blue,
            title: 'Send feedback',
            subtitle: 'Share ideas or suggestions',
            onTap: () { debugPrint('[HelpCenter] Tapped: Send feedback'); Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen())); },
          ),
          const SizedBox(height: 20),

          // ── FAQ ──
          _sectionLabel('FREQUENTLY ASKED', textMuted),
          _faqTile(context, card, border, textPrimary, textSecondary, textMuted,
            'How do I verify my account?',
            'Kora sends a 6-digit code to your email. Enter the code — verification is automatic on the last digit.',
          ),
          _faqTile(context, card, border, textPrimary, textSecondary, textMuted,
            'Is Kora AI really free?',
            'Yes. Kora AI — including translation, summaries, and chat assistance — is free for all users, no premium required.',
          ),
          _faqTile(context, card, border, textPrimary, textSecondary, textMuted,
            'How does end-to-end encryption work?',
            'Your messages are encrypted on your device and only decrypted on the recipient\'s device. Not even Kora can read them.',
          ),
          _faqTile(context, card, border, textPrimary, textSecondary, textMuted,
            'How do I restore my account?',
            'Your account is tied to your email and Kora ID. Reinstall the app, sign in with your email, and verify.',
          ),
          _faqTile(context, card, border, textPrimary, textSecondary, textMuted,
            'What is Kora Premium?',
            'Premium unlocks app icon switcher, custom themes, and future premium-only features. Kora AI remains free regardless.',
          ),
          const SizedBox(height: 20),

          // ── Contact ──
          _sectionLabel('CONTACT US', textMuted),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.email_outlined,
            iconColor: KoraColors.purple,
            title: 'Email support',
            subtitle: 'support@koramessenger.com',
            onTap: () { debugPrint('[HelpCenter] Tapped: Email support'); _launchUrl('mailto:support@koramessenger.com'); },
          ),
          const SizedBox(height: 8),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.privacy_tip_outlined,
            iconColor: KoraColors.blue,
            title: 'Privacy concerns',
            subtitle: 'privacy@koramessenger.com',
            onTap: () { debugPrint('[HelpCenter] Tapped: Privacy concerns email'); _launchUrl('mailto:privacy@koramessenger.com'); },
          ),
          const SizedBox(height: 8),
          _card(context, card, border, textPrimary, textSecondary,
            icon: Icons.gavel_outlined,
            iconColor: const Color(0xFF6B7280),
            title: 'Legal inquiries',
            subtitle: 'legal@koramessenger.com',
            onTap: () { debugPrint('[HelpCenter] Tapped: Legal inquiries email'); _launchUrl('mailto:legal@koramessenger.com'); },
          ),
          const SizedBox(height: 24),

          // ── Footer ──
          Center(
            child: Text(
              'Nexora Technologies',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Kora Messenger — Built for privacy',
              style: TextStyle(color: textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
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

  Widget _card(
    BuildContext context,
    Color card,
    Color border,
    Color textPrimary,
    Color textSecondary, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqTile(
    BuildContext context,
    Color card,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    String question,
    String answer,
  ) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      backgroundColor: card,
      collapsedBackgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 0.5),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 0.5),
      ),
      title: Text(question,
          style: TextStyle(
              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text(answer,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }
}

/// Report a bug screen — structured bug reporting.
class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  String _selectedCategory = 'App crash';
  final _descriptionController = TextEditingController();

  static const _categories = [
    'App crash',
    'Message not sending',
    'Call quality issue',
    'Login/verification issue',
    'Translation issue',
    'UI/display bug',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('[ReportBug] _submit() called');
    debugPrint('[ReportBug] Category: \$_selectedCategory');
    debugPrint('[ReportBug] Description length: \${_descriptionController.text.trim().length}');
    if (_descriptionController.text.trim().isEmpty) {
      debugPrint('[ReportBug] ⚠️ Submission blocked — empty description');
      return;
    }
    // Encode as mailto so it goes to support email with structured content
    final subject = Uri.encodeComponent('[Bug Report] $_selectedCategory');
    final body = Uri.encodeComponent(
        'Category: $_selectedCategory\n\nDescription:\n${_descriptionController.text}');
    final uri = Uri.parse('mailto:support@koramessenger.com?subject=$subject&body=$body');
    canLaunchUrl(uri).then((can) {
      if (can) launchUrl(uri, mode: LaunchMode.externalApplication);
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    debugPrint("[ReportBug] build() — ReportBugScreen rendered");
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
        title: Text('Report a bug',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Category', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () { debugPrint('[ReportBug] Category selected: $cat'); setState(() => _selectedCategory = cat); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? KoraColors.purple : card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? KoraColors.purple : border,
                      width: 1,
                    ),
                  ),
                  child: Text(cat,
                      style: TextStyle(
                        color: selected ? Colors.white : textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('What happened?',
              style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Describe the issue — what you were doing, what happened, and any error messages...',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              filled: true,
              fillColor: card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: KoraColors.purple, width: 1.5),
              ),
            ),
            style: TextStyle(color: textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _submit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Center(
                    child: Text('Submit report',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feedback screen — general suggestions and ideas.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('[Feedback] initState() — FeedbackScreen created');
  }

  @override
  void dispose() {
    debugPrint('[Feedback] dispose() — FeedbackScreen disposed');
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('[Feedback] _submit() called');
    debugPrint('[Feedback] Feedback text length: \${_controller.text.trim().length}');
    if (_controller.text.trim().isEmpty) {
      debugPrint('[Feedback] ⚠️ Submission blocked — empty feedback');
      return;
    }
    final subject = Uri.encodeComponent('[Feedback] Kora Messenger');
    final body = Uri.encodeComponent(_controller.text);
    final uri = Uri.parse('mailto:feedback@koramessenger.com?subject=$subject&body=$body');
    debugPrint('[Feedback] Constructed mailto URI: $uri');
    canLaunchUrl(uri).then((can) {
      debugPrint('[Feedback] canLaunchUrl => $can');
      if (can) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[Feedback] Feedback email launched successfully');
      } else {
        debugPrint('[Feedback] ⚠️ Could not launch email client');
      }
    });
    debugPrint('[Feedback] Popping screen, returning to Help Center');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Feedback] build() — FeedbackScreen rendered');
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Send feedback',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('We\'d love to hear from you',
              style: TextStyle(color: textMuted, fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Share your ideas, feature requests, or suggestions...',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              filled: true,
              fillColor: card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: KoraColors.purple, width: 1.5),
              ),
            ),
            style: TextStyle(color: textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: KoraColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _submit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Center(
                    child: Text('Send feedback',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
