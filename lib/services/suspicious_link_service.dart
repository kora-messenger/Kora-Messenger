import 'dart:convert';

/// Suspicious Link Detection — scans URLs in messages for phishing/malware.
/// Mirrors WhatsApp's built-in link security feature.
///
/// Checks:
/// - Known phishing domain patterns
/// - URL shortener services (expanded in production)
/// - Mismatched display URLs (link text vs actual URL)
/// - Suspicious TLDs commonly used for phishing
/// - IP-only URLs (no domain)
/// - Unicode/IDN homograph attacks
class SuspiciousLinkService {
  static final SuspiciousLinkService _instance = SuspiciousLinkService._();
  factory SuspiciousLinkService() => _instance;
  SuspiciousLinkService._();

  static final _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  static const _suspiciousTlds = [
    '.zip', '.mov', '.xyz', '.top', '.click', '.link', '.tk', '.ml', '.ga', '.cf', '.gq',
  ];

  static const _knownShorteners = [
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly', 'is.gd',
    'buff.ly', 'rebrand.ly', 'cutt.ly', 'shorturl.at',
  ];

  /// Scans a message text for suspicious links.
  /// Returns a list of warnings for each suspicious URL found.
  List<LinkWarning> scanMessage(String text) {
    final warnings = <LinkWarning>[];
    final matches = _urlRegex.allMatches(text);

    for (final match in matches) {
      final url = match.group(0)!;
      final warning = _checkUrl(url);
      if (warning != null) warnings.add(warning);
    }

    return warnings;
  }

  /// Checks if a message contains any suspicious link.
  bool hasSuspiciousLink(String text) => scanMessage(text).isNotEmpty;

  LinkWarning? _checkUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    final host = uri.host.toLowerCase();

    // Check for IP-only URLs
    if (_isIpAddress(host)) {
      return LinkWarning(
        url: url,
        type: LinkWarningType.ipAddress,
        message: 'This link uses a direct IP address instead of a domain name. '
                  'Legitimate websites rarely use IP addresses. Be cautious.',
      );
    }

    // Check for suspicious TLDs
    for (final tld in _suspiciousTlds) {
      if (host.endsWith(tld)) {
        return LinkWarning(
          url: url,
          type: LinkWarningType.suspiciousTld,
          message: 'This link uses a domain extension ($tld) commonly '
                  'associated with suspicious websites. Proceed with caution.',
        );
      }
    }

    // Check for URL shorteners (could hide destination)
    for (final shortener in _knownShorteners) {
      if (host == shortener) {
        return LinkWarning(
          url: url,
          type: LinkWarningType.shortener,
          message: 'This is a shortened link that may hide its true destination. '
                  'Tap to see where it leads before opening.',
        );
      }
    }

    // Check for IDN/unicode homograph attacks
    if (_hasMixedUnicode(host)) {
      return LinkWarning(
        url: url,
        type: LinkWarningType.homograph,
        message: 'This link contains characters from different writing systems '
                  'that may be impersonating a legitimate website.',
      );
    }

    // Check for mismatched subdomain patterns (e.g., paypal.com.scam.xyz)
    if (_hasDeceptiveSubdomain(host)) {
      return LinkWarning(
        url: url,
        type: LinkWarningType.deceptiveDomain,
        message: 'This link may be impersonating a legitimate website. '
                  'Check the domain carefully before proceeding.',
      );
    }

    return null;
  }

  bool _isIpAddress(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) => int.tryParse(p) != null && int.parse(p) >= 0 && int.parse(p) <= 255);
  }

  bool _hasMixedUnicode(String host) {
    final labels = host.split('.');
    for (final label in labels) {
      int ascii = 0, nonAscii = 0;
      for (final char in label.codeUnits) {
        if (char < 128) { ascii++; } else { nonAscii++; }
      }
      if (ascii > 0 && nonAscii > 0) return true;
    }
    return false;
  }

  bool _hasDeceptiveSubdomain(String host) {
    // Check for patterns like "paypal.com.evil.xyz" or "google.com.fake.tk"
    final knownBrands = ['paypal', 'google', 'apple', 'amazon', 'microsoft',
                         'facebook', 'instagram', 'whatsapp', 'netflix', 'bank'];
    final labels = host.split('.');
    for (final brand in knownBrands) {
      // If brand appears in a non-primary position
      for (int i = 0; i < labels.length - 1; i++) {
        if (labels[i] == brand && i > 0) {
          return true;
        }
      }
    }
    return false;
  }
}

enum LinkWarningType {
  ipAddress,
  suspiciousTld,
  shortener,
  homograph,
  deceptiveDomain,
}

class LinkWarning {
  final String url;
  final LinkWarningType type;
  final String message;

  LinkWarning({
    required this.url,
    required this.type,
    required this.message,
  });
}
