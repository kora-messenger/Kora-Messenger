import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../config/subscription_pricing.dart';
import '../../services/pricing_service.dart';

/// Billing / payment method screen.
///
/// Shown when the user taps "Subscribe" from the Premium sheet.
/// Displays the selected plan summary with the correct regional price
/// and payment method selection.
class BillingScreen extends StatefulWidget {
  final SubscriptionPlan selectedPlan;

  const BillingScreen({
    super.key,
    required this.selectedPlan,
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  int _selectedMethod = 0;
  RegionalPrice? _price;
  bool _loadingPrice = true;

  static const List<_PaymentMethod> _methods = [
    _PaymentMethod(icon: Icons.credit_card, name: 'Credit / Debit Card', subtitle: 'Visa, Mastercard, Amex'),
    _PaymentMethod(icon: Icons.account_balance_wallet_outlined, name: 'Google Pay', subtitle: 'Pay with your Google account'),
    _PaymentMethod(icon: Icons.phone_android, name: 'Carrier Billing', subtitle: 'Charge to your phone bill'),
  ];

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

  String get _planTitle {
    return widget.selectedPlan == SubscriptionPlan.monthly ? 'Monthly' : 'Yearly';
  }

  String get _billingPeriod {
    return widget.selectedPlan == SubscriptionPlan.monthly ? 'Billed monthly' : 'Billed yearly';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: AppBar(
        backgroundColor: KoraColors.trueBlack,
        elevation: 0,
        title: const Text(
          'Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Plan summary ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: KoraColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: KoraColors.purple.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: KoraColors.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kora Premium — $_planTitle',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _billingPeriod,
                                style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (_price != null)
                          Text(
                            _price!.priceForPlan(widget.selectedPlan),
                            style: const TextStyle(
                              color: KoraColors.purple,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (_price != null && widget.selectedPlan == SubscriptionPlan.yearly) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: KoraColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.savings_outlined, color: KoraColors.purple, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'You save ${_price!.yearlySavingsPercent}% with yearly',
                              style: const TextStyle(
                                color: KoraColors.purple,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Payment methods ──
              const Text(
                'Select payment method',
                style: TextStyle(
                  color: Color(0xFFA0A0B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),

              ...List.generate(_methods.length, (i) {
                final method = _methods[i];
                final isSelected = _selectedMethod == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMethod = i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: KoraColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? KoraColors.purple : const Color(0xFF2A2A3A),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(method.icon, color: isSelected ? KoraColors.purple : const Color(0xFFA0A0B8), size: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                method.subtitle,
                                style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? KoraColors.purple : const Color(0xFF4A4A5E),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: KoraColors.purple,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Spacer(),

              // ── Pay button ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: GestureDetector(
                  onTap: _loadingPrice
                      ? null
                      : () {
                          _showComingSoon('Payment');
                        },
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
                                  ? 'Pay ${_price!.priceForPlan(widget.selectedPlan)} & Subscribe'
                                  : 'Pay & Subscribe',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethod {
  final IconData icon;
  final String name;
  final String subtitle;
  const _PaymentMethod({required this.icon, required this.name, required this.subtitle});
}
