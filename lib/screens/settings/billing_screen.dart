import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// Billing / payment method screen.
///
/// Shown when the user taps "Subscribe and pay" from the Premium sheet.
/// Price will be configured later — for now it shows the UI scaffold
/// with a placeholder price and payment method selection.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  int _selectedMethod = 0;

  static const List<_PaymentMethod> _methods = [
    _PaymentMethod(icon: Icons.credit_card, name: 'Credit / Debit Card', subtitle: 'Visa, Mastercard, Amex'),
    _PaymentMethod(icon: Icons.account_balance_wallet_outlined, name: 'Google Pay', subtitle: 'Pay with your Google account'),
    _PaymentMethod(icon: Icons.phone_android, name: 'Carrier Billing', subtitle: 'Charge to your phone bill'),
  ];

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
                  border: Border.all(color: const Color(0xFF2E2E42), width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: KoraColors.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kora Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Price coming soon',
                            style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: KoraColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Premium',
                        style: TextStyle(
                          color: KoraColors.purple,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Payment methods ──
              const Text(
                'SELECT PAYMENT METHOD',
                style: TextStyle(
                  color: Color(0xFF6B6B80),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              ...List.generate(_methods.length, (index) {
                final method = _methods[index];
                final isSelected = index == _selectedMethod;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMethod = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: KoraColors.darkCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? KoraColors.purple : const Color(0xFF2E2E42),
                          width: isSelected ? 2 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(method.icon, color: isSelected ? KoraColors.purple : const Color(0xFFA0A0B8), size: 24),
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
                          // Radio indicator
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
                  ),
                );
              }),

              const Spacer(),

              // ── Pay button ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: GestureDetector(
                  onTap: () => _showComingSoon('Payment'),
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
                    child: const Center(
                      child: Text(
                        'Pay & Subscribe',
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
    );
  }
}

class _PaymentMethod {
  final IconData icon;
  final String name;
  final String subtitle;
  const _PaymentMethod({required this.icon, required this.name, required this.subtitle});
}
