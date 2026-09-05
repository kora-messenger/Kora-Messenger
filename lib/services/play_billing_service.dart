// Google Play Billing service for Kora Premium.
//
// Offers Google Play as a payment method alongside the existing
// Paystack checkout. Purchases are verified server-side via the
// koraPlayBilling endpoint (Google Play Developer API) before
// premium is granted — the client is never trusted.
//
// Availability: Play Billing only works for apps installed from the
// Play Store with billing configured. On sideloaded builds (GitHub
// APK releases) the service reports unavailable and the UI hides the
// Google payment option cleanly.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/kora_api.dart';

/// Product IDs on Google Play Console — must match the subscription
/// products created there (base plans: monthly / yearly).
class PlayBillingProducts {
  static const monthly = 'kora_premium_monthly';
  static const yearly = 'kora_premium_yearly';
}

class PlayBillingService {
  PlayBillingService._();
  static final PlayBillingService instance = PlayBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = {};

  bool _initialized = false;
  bool _available = false;

  /// The email used for server verification — set during buy().
  String _verifyEmail = '';

  /// Whether Google Play Billing can be offered on this device.
  bool get available => _available && _products.isNotEmpty;

  /// The loaded Play Store products (prices come from Play Console
  /// regional pricing — authoritative for the Google payment method).
  List<ProductDetails> get products {
    final list = _products.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  Completer<Map<String, dynamic>?>? _pendingVerify;

  /// Initializes the billing connection. Safe to call repeatedly.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _available = await _iap.isAvailable();

      if (!_available) {
        debugPrint('[play_billing] Play Billing not available on this device');
        return;
      }

      _sub = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (e) => debugPrint('[play_billing] purchase stream error: $e'),
      );

      final response = await _iap.queryProductDetails({
        PlayBillingProducts.monthly,
        PlayBillingProducts.yearly,
      });

      if (response.error != null) {
        debugPrint('[play_billing] query error: ${response.error!.message}');
        return;
      }

      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      debugPrint('[play_billing] loaded ${_products.length} products');
    } catch (e) {
      debugPrint('[play_billing] init failed: $e');
      _available = false;
    }
  }

  /// Starts a purchase for the given plan. Returns the server
  /// verification result (null if the flow was cancelled/failed).
  Future<Map<String, dynamic>?> buy({
    required bool yearly,
    required String userEmail,
  }) async {
    _verifyEmail = userEmail;
    final productId = yearly ? PlayBillingProducts.yearly : PlayBillingProducts.monthly;
    final product = _products[productId];
    if (product == null) return null;

    _pendingVerify = Completer<Map<String, dynamic>?>();
    final param = PurchaseParam(productDetails: product);

    // Subscriptions:
    await _iap.buyNonConsumable(purchaseParam: param);
    return _pendingVerify!.future;
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final result = await _verifyWithServer(purchase);
          if (_pendingVerify != null && !_pendingVerify!.isCompleted) {
            _pendingVerify!.complete(result);
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[play_billing] purchase error: ${purchase.error?.code}');
          if (_pendingVerify != null && !_pendingVerify!.isCompleted) {
            _pendingVerify!.complete(null);
          }
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          if (_pendingVerify != null && !_pendingVerify!.isCompleted) {
            _pendingVerify!.complete(null);
          }
          break;
      }
    }
  }

  /// Server-side verification — the backend checks the purchase token
  /// against Google Play and grants premium. Never trusted locally.
  Future<Map<String, dynamic>?> _verifyWithServer(PurchaseDetails purchase) async {
    try {
      final response = await http.post(
        Uri.parse(KoraApi.playBillingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyPurchase',
          'userEmail': _verifyEmail,
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
        }),
      ).timeout(const Duration(seconds: 20));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[play_billing] verify failed: $e');
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
