import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../theme/kora_colors.dart';

/// Premium subscription bottom sheet.
///
/// Shows all Premium benefits, legal text with clickable links
/// (Terms of Service, Privacy Policy, Learn more — all show "coming soon"),
/// and a "Subscribe and pay" button that opens the billing screen.
class PremiumSubscribeSheet extends StatefulWidget {
  const PremiumSubscribeSheet({super.key});

  @override
  State<PremiumSubscribeSheet> createState() => _PremiumSubscribeSheetState();
}

class _PremiumSubscribeSheetState extends State<PremiumSubscribeSheet> {
  void _showComingSoon(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '$title is coming soon. Stay tuned!',
          style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _onSubscribe() {
    // Return true to signal the parent to navigate to billing
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: KoraColors.trueBlack,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E3E52),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Premium header ──
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kora Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unlock the full Kora experience',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                const SizedBox(height: 28),

                // ── Benefits list ──
                _benefitRow(Icons.palette_outlined, 'Custom app icons', 'Choose from 10 exclusive Kora app icons'),
                _benefitRow(Icons.color_lens_outlined, '20 premium app themes', 'Personalize your entire app with premium colors'),
                _benefitRow(Icons.chat_bubble_outline, 'Custom chat bubbles', 'Express yourself with unique bubble colors'),
                _benefitRow(Icons.image_outlined, 'Premium wallpapers', 'Exclusive wallpaper collection'),
                _benefitRow(Icons.flash_on_outlined, 'Priority support', 'Get faster responses from our team'),
                _benefitRow(Icons.lock_open_outlined, 'No ads', 'Enjoy a clean, ad-free experience'),
                const SizedBox(height: 28),

                // ── Legal text ──
                // Paragraph 1: "By continuing, you agree to Kora Terms of Service"
                // Paragraph 2: "and Privacy Policy."
                // Paragraph 3: "This Kora subscription renews until"
                // Paragraph 4: "canceled. Learn more"
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5, height: 1.5),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to Kora '),
                      _linkSpan('Terms of Service'),
                      const TextSpan(text: '\n'),
                      _linkSpan('Privacy Policy'),
                      const TextSpan(text: '.'),
                      const TextSpan(text: '\n\n'),
                      const TextSpan(text: 'This Kora subscription renews until\n'),
                      _linkSpan('canceled'),
                      const TextSpan(text: '. '),
                      _linkSpan('Learn more'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Subscribe and pay button ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: GestureDetector(
                    onTap: _onSubscribe,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: KoraColors.brandGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: KoraColors.purple.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: const Text(
                                'Subscribe and pay',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: KoraColors.purple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.check, color: KoraColors.purple, size: 18),
        ],
      ),
    );
  }

  /// Creates a clickable TextSpan that shows a "coming soon" dialog.
  TextSpan _linkSpan(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: KoraColors.purple,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: KoraColors.purple,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _showComingSoon(text),
    );
  }
}
