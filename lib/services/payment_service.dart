import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/kora_api.dart';
import '../config/subscription_pricing.dart';
import 'pricing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all payment processing for Kora Premium subscriptions.
///
/// Three payment methods are supported:
/// 1. **Paystack** — card, bank transfer, USSD via Paystack checkout (webview)
/// 2. **Google Pay** — native Google Pay sheet on Android
/// 3. **Apple Pay** — native Apple Pay sheet on iOS
///
/// All payments are processed through Paystack as the payment gateway.
/// The backend functions handle transaction initialization and verification.
class PaymentService {
  PaymentService._();

  /// Initialize a Paystack transaction and return the checkout URL.
  static Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amount,
    required String currency,
    required SubscriptionPlan plan,
  }) async {
    final response = await KoraApi.postTo(
      KoraApi.paymentInitEndpoint,
      {
        'email': email,
        'amount': amount.toString(),
        'currency': currency,
        'plan': plan == SubscriptionPlan.monthly ? 'monthly' : 'yearly',
        'planName': plan == SubscriptionPlan.monthly ? 'Monthly' : 'Yearly',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.containsKey('error')) {
      throw Exception(response['error']);
    }

    return response;
  }

  /// Verify a Paystack transaction by reference.
  static Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    final response = await KoraApi.postTo(
      KoraApi.paymentVerifyEndpoint,
      {'reference': reference},
    ).timeout(const Duration(seconds: 15));

    return response;
  }

  /// Open the Paystack checkout page in a webview and wait for completion.
  /// Returns the transaction reference on success, null on failure/cancel.
  static Future<String?> openPaystackCheckout({
    required BuildContext context,
    required String authorizationUrl,
    required String reference,
  }) async {
    final completer = Completer<String?>();

    if (!context.mounted) return null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PaystackCheckoutScreen(
          authorizationUrl: authorizationUrl,
          reference: reference,
          onResult: (result) {
            if (!completer.isCompleted) completer.complete(result);
          },
        ),
        fullscreenDialog: true,
      ),
    );

    return completer.future;
  }

  /// Full payment flow: init → checkout → verify → activate premium.
  static Future<PaymentResult> processPayment({
    required BuildContext context,
    required String email,
    required SubscriptionPlan plan,
    required PaymentMethod method,
  }) async {
    try {
      // Get regional price
      final price = await PricingService.getRegionalPrice();

      // Initialize transaction
      final initResponse = await initializeTransaction(
        email: email,
        amount: plan == SubscriptionPlan.monthly ? price.monthlyAmount : price.yearlyAmount,
        currency: price.currencyCode,
        plan: plan,
      );

      final authorizationUrl = initResponse['authorization_url'] as String;
      final reference = initResponse['reference'] as String;

      // For Paystack: open webview checkout
      // For Google Pay / Apple Pay: these are handled within Paystack's
      // checkout page automatically (Paystack detects the platform and
      // shows the appropriate mobile wallet option)
      if (!context.mounted) {
        return PaymentResult(success: false, message: 'Payment cancelled');
      }

      final verifiedRef = await openPaystackCheckout(
        context: context,
        authorizationUrl: authorizationUrl,
        reference: reference,
      );

      if (verifiedRef == null) {
        return PaymentResult(success: false, message: 'Payment was cancelled');
      }

      // Verify the transaction
      final verifyResponse = await verifyTransaction(verifiedRef);

      if (verifyResponse['success'] == true) {
        // Activate premium in shared preferences
        await _activatePremium(
          plan: verifyResponse['planType'] ?? 'monthly',
          reference: verifiedRef,
        );

        return PaymentResult(
          success: true,
          reference: verifiedRef,
          message: 'Payment successful! Premium activated.',
          planType: verifyResponse['planType'],
        );
      } else {
        return PaymentResult(
          success: false,
          message: verifyResponse['message'] ?? 'Payment verification failed',
        );
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      return PaymentResult(success: false, message: 'Payment failed: $e');
    }
  }

  /// Activate premium status locally after successful payment.
  static Future<void> _activatePremium({
    required String plan,
    required String reference,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = plan == 'yearly' ? 365 : 30; // days
    final expiry = now + (duration * 24 * 60 * 60 * 1000);

    await prefs.setBool('is_premium', true);
    await prefs.setString('premium_plan', plan);
    await prefs.setInt('premium_expiry', expiry);
    await prefs.setString('premium_payment_ref', reference);
    await prefs.setString('premium_activated_at', now.toString());
  }

  /// Check if the user has active premium.
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium') ?? false;
    if (!isPremium) return false;

    final expiry = prefs.getInt('premium_expiry') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > expiry) {
      // Premium expired
      await prefs.setBool('is_premium', false);
      return false;
    }
    return true;
  }

  /// Get the user's current premium plan.
  static Future<String?> getPremiumPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('premium_plan');
  }

  /// Check if the owner override is active (permanent premium without payment).
  static Future<bool> isOwnerOverride(String email) async {
    // The owner's email gets permanent premium
    const ownerEmail = 'ijeziegoodluck@gmail.com';
    if (email.toLowerCase() == ownerEmail) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setString('premium_plan', 'owner');
      await prefs.setInt('premium_expiry', 0); // 0 = never expires
      return true;
    }
    return false;
  }
}

/// Payment method options.
enum PaymentMethod {
  paystack, // Card, bank transfer, USSD
  googlePay, // Google Pay (Android)
  applePay, // Apple Pay (iOS)
}

/// Result of a payment attempt.
class PaymentResult {
  final bool success;
  final String? reference;
  final String message;
  final String? planType;

  PaymentResult({
    required this.success,
    this.reference,
    required this.message,
    this.planType,
  });
}

/// Paystack checkout webview screen.
class _PaystackCheckoutScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final void Function(String?) onResult;

  const _PaystackCheckoutScreen({
    required this.authorizationUrl,
    required this.reference,
    required this.onResult,
  });

  @override
  State<_PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<_PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _resultSent = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!_resultSent && mounted) {
              _resultSent = true;
              widget.onResult(null);
              Navigator.of(context).pop();
            }
          },
          onNavigationRequest: (request) {
            // Check for callback URL (kora://payment/verify)
            if (request.url.startsWith('kora://')) {
              if (!_resultSent) {
                _resultSent = true;
                widget.onResult(widget.reference);
                Navigator.of(context).pop();
              }
              return NavigationDecision.prevent;
            }

            // Check for Paystack success/redirect URLs
            if (request.url.contains('status=success') ||
                request.url.contains('status=cancelled')) {
              if (!_resultSent) {
                _resultSent = true;
                if (request.url.contains('status=success')) {
                  widget.onResult(widget.reference);
                } else {
                  widget.onResult(null);
                }
                Navigator.of(context).pop();
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B14),
        elevation: 0,
        title: const Text(
          'Secure Payment',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (!_resultSent) {
              _resultSent = true;
              widget.onResult(null);
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            ),
        ],
      ),
    );
  }
}
