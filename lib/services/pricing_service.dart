import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../config/subscription_pricing.dart';

/// Detects the user's country and returns the correct regional pricing.
///
/// Strategy:
///   1. Check device locale's country code (fast, offline)
///   2. If that fails or isn't specific enough, query an IP geolocation API
///   3. Cache the result for the session
///
/// Domain-swappable: the geolocation API URL is centralized here.
/// When you move to your own domain, you can replace this with your
/// own geo-IP endpoint or remove it entirely.
class PricingService {
  PricingService._();

  static RegionalPrice? _cachedPrice;
  static String? _cachedCountryCode;

  /// Returns the regional price for the current user.
  /// Uses device locale first, then IP geolocation as fallback.
  static Future<RegionalPrice> getRegionalPrice() async {
    if (_cachedPrice != null) return _cachedPrice!;

    // Step 1: Try device locale
    final locale = PlatformDispatcher.instance.locale;
    final localeCountry = locale.countryCode;
    if (localeCountry != null && localeCountry.isNotEmpty) {
      final price = SubscriptionPricing.getPriceForCountry(localeCountry);
      if (price.currencyCode != 'USD' || localeCountry.toUpperCase() == 'US') {
        _cachedPrice = price;
        _cachedCountryCode = localeCountry.toUpperCase();
        return price;
      }
    }

    // Step 2: Try IP geolocation
    try {
      final countryCode = await _detectCountryViaIp();
      if (countryCode != null) {
        final price = SubscriptionPricing.getPriceForCountry(countryCode);
        _cachedPrice = price;
        _cachedCountryCode = countryCode;
        return price;
      }
    } catch (_) {
      // Network error — fall through to default
    }

    // Fallback: USD default
    _cachedPrice = SubscriptionPricing.defaultPrice;
    _cachedCountryCode = 'US';
    return _cachedPrice!;
  }

  /// Returns the cached country code (null if not yet resolved).
  static String? get cachedCountryCode => _cachedCountryCode;

  /// Clears the cache so the next call re-detects.
  static void clearCache() {
    _cachedPrice = null;
    _cachedCountryCode = null;
  }

  /// Detects the user's country via IP geolocation.
  /// Uses the free ipapi.co service (no API key needed).
  ///
  /// Domain-swappable: replace this URL with your own geo-IP endpoint
  /// when you have your own server.
  static Future<String?> _detectCountryViaIp() async {
    final response = await http
        .get(Uri.parse('https://ipapi.co/json/'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final country = data['country_code'] as String?;
      return country?.toUpperCase();
    }
    return null;
  }
}
