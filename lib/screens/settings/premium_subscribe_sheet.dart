import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/kora_colors.dart';
import '../../config/kora_api.dart';
import '../../config/subscription_pricing.dart';
import '../../services/pricing_service.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';
import '../../theme/chat_theme_provider.dart';

/// Premium subscription bottom sheet.
///
/// Shows all Premium benefits, a monthly/yearly plan toggle with
/// location-based pricing, legal text with clickable links, and a
/// "Subscribe and pay" button that opens the billing screen with
/// the selected plan.
class PremiumSubscribeSheet extends StatefulWidget {
  const PremiumSubscribeSheet({super.key});

  /// Opens the Premium subscribe sheet from anywhere in the app —
  /// used by the tappable Premium badge so it behaves the same way
  /// no matter where that badge is shown (chat list, contact list,
  /// profile, search results, etc.).
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PremiumSubscribeSheet(),
    );
  }

  @override
  State<PremiumSubscribeSheet> createState() => _PremiumSubscribeSheetState();
}

class _PremiumSubscribeSheetState extends State<PremiumSubscribeSheet> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.yearly;
  RegionalPrice? _price;
  bool _loadingPrice = true;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final price = await PricingService.getRegionalPrice();
    if (mounted) {
      setState(() {
        _price = price;
        _loadingPrice = false;
      });
    }
  }

  Future<void> _launchLegalUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onSubscribe() {
    Navigator.pop(context, _selectedPlan);
  }

  Future<void> _recoverSubscription() async {
    setState(() => _recovering = true);

    try {
      final session = await SessionManager.instance.loadSession();
      final userId = session?['id']?.toString() ?? '';
      final email = (session?['email'] as String?)?.toLowerCase().trim() ?? '';

      if (userId.isEmpty && email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to recover your subscription.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final result = await PaymentService.recoverSubscription(
        userId: userId,
        email: email,
      );

      if (mounted) {
        if (result.success) {
          // Pop the sheet and show success
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: KoraColors.purple,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: const Color(0xFF2A2A3A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to Kora servers. Try again later.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
            child: SingleChildScrollView(
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
                const SizedBox(height: 24),

                // ── Plan toggle ──
                _buildPlanToggle(),
                const SizedBox(height: 24),

                // ── Benefits list ──
                _benefitRow(Icons.palette_outlined, 'Custom app icons', 'Choose from 10 exclusive Kora app icons'),
                _benefitRow(Icons.color_lens_outlined, '20 premium app themes', 'Personalize your entire app with premium colors'),
                _benefitRow(Icons.chat_bubble_outline, 'Custom chat bubbles', 'Express yourself with unique bubble colors'),
                _benefitRow(Icons.image_outlined, 'Premium wallpapers', 'Exclusive wallpaper collection'),
                _benefitRow(Icons.flash_on_outlined, 'Priority support', 'Get faster responses from our team'),
                _benefitRow(Icons.lock_open_outlined, 'No ads', 'Enjoy a clean, ad-free experience'),
                _benefitRow(
                  Icons.favorite_rounded,
                  'Infinite Reactions',
                  'React with thousands of emoji — with multiple reactions per message.',
                ),
                _benefitRow(
                  Icons.speed_rounded,
                  'Faster Download Speed',
                  'No more limits on the speed with which media and documents are downloaded.',
                ),
                _benefitRow(
                  Icons.translate_rounded,
                  'Real-Time Translation',
                  'Real-time translation of channels and chats into other languages.',
                ),
                _benefitRow(
                  Icons.emoji_emotions_outlined,
                  'Animated Emoji',
                  'Include animated emoji from different emoji sets in any message you send.',
                ),
                _benefitRow(
                  Icons.star_rounded,
                  'Profile Badge',
                  'A badge next to your name showing that you are helping support Kora.',
                ),
                const SizedBox(height: 28),

                // ── Legal text ──
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

                // ── Subscribe button ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: GestureDetector(
                    onTap: _loadingPrice ? null : _onSubscribe,
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
                        child: _loadingPrice
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _price != null
                                    ? 'Subscribe for ${_price!.priceForPlan(_selectedPlan)}'
                                    : 'Subscribe and pay',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Recover Subscription ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _recovering ? null : _recoverSubscription,
                    icon: _recovering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFFA0A0B8),
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.restore_outlined, color: Color(0xFFA0A0B8), size: 20),
                    label: Text(
                      _recovering ? 'Checking...' : 'Recover Subscription',
                      style: const TextStyle(
                        color: Color(0xFFA0A0B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
      ),
    );
  }

  /// Plan selection toggle — Monthly vs Yearly with prices.
  Widget _buildPlanToggle() {
    if (_loadingPrice || _price == null) {
      return Container(
        height: 88,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _planCard(
            plan: SubscriptionPlan.monthly,
            title: 'Monthly',
            priceText: _price!.priceForPlan(SubscriptionPlan.monthly),
            period: '/month',
            badge: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _planCard(
            plan: SubscriptionPlan.yearly,
            title: 'Yearly',
            priceText: _price!.priceForPlan(SubscriptionPlan.yearly),
            period: '/year',
            badge: 'Save ${_price!.yearlySavingsPercent}%',
            subtitle: '${_price!.yearlyPerMonth()}/month',
          ),
        ),
      ],
    );
  }

  Widget _planCard({
    required SubscriptionPlan plan,
    required String title,
    required String priceText,
    required String period,
    String? badge,
    String? subtitle,
  }) {
    final isSelected = _selectedPlan == plan;
    final borderColor = isSelected ? KoraColors.purple : const Color(0xFF2A2A3A);
    final bgColor = isSelected ? KoraColors.purple.withValues(alpha: 0.08) : Colors.transparent;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1.5),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFA0A0B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: KoraColors.brandGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceText,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFE0E0F0),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  period,
                  style: TextStyle(
                    color: const Color(0xFFA0A0B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? KoraColors.purple.withValues(alpha: 0.9) : const Color(0xFF6B6B80),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
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

  TextSpan _linkSpan(String text) {
    final String url;
    switch (text) {
      case 'Terms of Service':
        url = KoraApi.termsOfServiceUrl;
        break;
      case 'Privacy Policy':
        url = KoraApi.privacyPolicyUrl;
        break;
      case 'EULA':
        url = KoraApi.eulaUrl;
        break;
      case 'E2EE Disclosure':
        url = KoraApi.e2eePolicyUrl;
        break;
      case 'canceled':
        url = KoraApi.learnMoreUrl;
        break;
      case 'Learn more':
        url = KoraApi.learnMoreUrl;
        break;
      default:
        url = KoraApi.learnMoreUrl;
    }
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
        ..onTap = () => _launchLegalUrl(url),
    );
  }
}
