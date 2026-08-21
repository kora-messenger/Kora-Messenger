/// Central subscription pricing configuration for Kora Premium.
///
/// All prices are centralized here. When migrating to a custom domain,
/// update [KoraApi.baseUrl] and the backend subscription endpoint —
/// the pricing structure stays the same.
///
/// To add a new region/currency:
///   1. Add an entry to [SubscriptionPricing.regionalPricing] with the
///      country code → RegionalPrice mapping
///   2. Specify monthly and yearly prices in that currency
///   3. The UI will automatically pick it up
library;

/// Subscription plan types.
enum SubscriptionPlan { monthly, yearly }

/// A regional price for Kora Premium.
class RegionalPrice {
  /// ISO 4217 currency code, e.g. 'NGN', 'USD', 'EUR'
  final String currencyCode;

  /// Currency symbol for display, e.g. '₦', '$', '€'
  final String currencySymbol;

  /// Monthly price in the local currency
  final double monthlyAmount;

  /// Yearly price in the same currency (already discounted)
  final double yearlyAmount;

  /// Yearly savings percentage vs. monthly (for display)
  final int yearlySavingsPercent;

  /// Locale string for number formatting, e.g. 'en_NG', 'en_US'
  final String locale;

  const RegionalPrice({
    required this.currencyCode,
    required this.currencySymbol,
    required this.monthlyAmount,
    required this.yearlyAmount,
    required this.yearlySavingsPercent,
    required this.locale,
  });

  /// Formats a price amount with the currency symbol.
  /// e.g. 3000 → '₦3,000', 3 → '$3.00'
  String formatPrice(double amount) {
    if (currencyCode == 'USD' || currencyCode == 'EUR' || currencyCode == 'GBP') {
      return '$currencySymbol${amount.toStringAsFixed(2)}';
    }
    return '$currencySymbol${amount.toStringAsFixed(0)}';
  }

  /// Returns the price for the given plan.
  String priceForPlan(SubscriptionPlan plan) {
    return formatPrice(plan == SubscriptionPlan.monthly ? monthlyAmount : yearlyAmount);
  }

  /// Returns a per-month breakdown for the yearly plan.
  String yearlyPerMonth() {
    final perMonth = yearlyAmount / 12;
    return formatPrice(perMonth);
  }
}

/// Subscription pricing — centralized config.
///
/// Default (fallback) prices are in USD.
/// Regional prices are keyed by ISO 3166-1 alpha-2 country codes.
class SubscriptionPricing {
  SubscriptionPricing._();

  /// Default USD pricing — used when the user's country isn't in the
  /// regional map, or as a fallback.
  static const RegionalPrice defaultPrice = RegionalPrice(
    currencyCode: 'USD',
    currencySymbol: '\$',
    monthlyAmount: 3.00,
    yearlyAmount: 30.60,
    yearlySavingsPercent: 15,
    locale: 'en_US',
  );

  /// Regional pricing map.
  /// Key = ISO 3166-1 alpha-2 country code.
  /// Add entries here to support new regions.
  static const Map<String, RegionalPrice> regionalPricing = {
    // Nigeria
    'NG': RegionalPrice(
      currencyCode: 'NGN',
      currencySymbol: '₦',
      monthlyAmount: 3000,
      yearlyAmount: 30600,
      yearlySavingsPercent: 15,
      locale: 'en_NG',
    ),
    // Ghana
    'GH': RegionalPrice(
      currencyCode: 'GHS',
      currencySymbol: '₵',
      monthlyAmount: 35,
      yearlyAmount: 357,
      yearlySavingsPercent: 15,
      locale: 'en_GH',
    ),
    // Kenya
    'KE': RegionalPrice(
      currencyCode: 'KES',
      currencySymbol: 'KSh',
      monthlyAmount: 450,
      yearlyAmount: 4590,
      yearlySavingsPercent: 15,
      locale: 'en_KE',
    ),
    // South Africa
    'ZA': RegionalPrice(
      currencyCode: 'ZAR',
      currencySymbol: 'R',
      monthlyAmount: 55,
      yearlyAmount: 561,
      yearlySavingsPercent: 15,
      locale: 'en_ZA',
    ),
    // United Kingdom
    'GB': RegionalPrice(
      currencyCode: 'GBP',
      currencySymbol: '£',
      monthlyAmount: 2.50,
      yearlyAmount: 25.50,
      yearlySavingsPercent: 15,
      locale: 'en_GB',
    ),
    // Eurozone
    'DE': RegionalPrice(
      currencyCode: 'EUR',
      currencySymbol: '€',
      monthlyAmount: 2.80,
      yearlyAmount: 28.56,
      yearlySavingsPercent: 15,
      locale: 'de_DE',
    ),
    'FR': RegionalPrice(
      currencyCode: 'EUR',
      currencySymbol: '€',
      monthlyAmount: 2.80,
      yearlyAmount: 28.56,
      yearlySavingsPercent: 15,
      locale: 'fr_FR',
    ),
    'ES': RegionalPrice(
      currencyCode: 'EUR',
      currencySymbol: '€',
      monthlyAmount: 2.80,
      yearlyAmount: 28.56,
      yearlySavingsPercent: 15,
      locale: 'es_ES',
    ),
    'IT': RegionalPrice(
      currencyCode: 'EUR',
      currencySymbol: '€',
      monthlyAmount: 2.80,
      yearlyAmount: 28.56,
      yearlySavingsPercent: 15,
      locale: 'it_IT',
    ),
    // India
    'IN': RegionalPrice(
      currencyCode: 'INR',
      currencySymbol: '₹',
      monthlyAmount: 249,
      yearlyAmount: 2539,
      yearlySavingsPercent: 15,
      locale: 'en_IN',
    ),
    // Canada
    'CA': RegionalPrice(
      currencyCode: 'CAD',
      currencySymbol: 'C\$',
      monthlyAmount: 4.00,
      yearlyAmount: 40.80,
      yearlySavingsPercent: 15,
      locale: 'en_CA',
    ),
    // Australia
    'AU': RegionalPrice(
      currencyCode: 'AUD',
      currencySymbol: 'A\$',
      monthlyAmount: 4.50,
      yearlyAmount: 45.90,
      yearlySavingsPercent: 15,
      locale: 'en_AU',
    ),
    // United States
    'US': RegionalPrice(
      currencyCode: 'USD',
      currencySymbol: '\$',
      monthlyAmount: 3.00,
      yearlyAmount: 30.60,
      yearlySavingsPercent: 15,
      locale: 'en_US',
    ),
  };

  /// Returns the regional price for the given country code.
  /// Falls back to USD pricing if the country isn't configured.
  static RegionalPrice getPriceForCountry(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return defaultPrice;
    return regionalPricing[countryCode.toUpperCase()] ?? defaultPrice;
  }
}
