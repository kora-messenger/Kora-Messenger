import 'dart:math';

/// Mock authentication service for Kora Messenger.
///
/// Simulates email verification codes sent from koramessengerofficial@gmail.com.
/// When a real backend is ready, replace the methods here with API calls.
class AuthService {
  static const String senderEmail = 'koramessengerofficial@gmail.com';

  // ── Singleton ──────────────────────────────────────────────
  static final AuthService instance = AuthService._();
  AuthService._();

  // ── In-memory state (mock) ──────────────────────────────────
  String? _currentCode;
  DateTime? _codeGeneratedAt;
  int _attempts = 0;
  static const int _maxAttempts = 5;
  static const Duration _codeExpiry = Duration(minutes: 10);
  static const Duration _resendCooldown = Duration(seconds: 60);

  /// Generates a 6-digit verification code, stores it, and "sends" it.
  String sendVerificationCode(String userEmail) {
    final rng = Random();
    _currentCode = (rng.nextInt(900000) + 100000).toString();
    _codeGeneratedAt = DateTime.now();
    _attempts = 0;

    // In production: call backend to send email from koramessengerofficial@gmail.com
    // ignore: avoid_print
    print('=== Kora Verification Code ===');
    print('  To: $userEmail');
    print('  From: $senderEmail');
    print('  Code: $_currentCode');
    print('  Expires: ${_codeExpiry.inMinutes} minutes');
    print('==============================');

    return _currentCode!;
  }

  /// Validates the code entered by the user.
  VerificationResult verifyCode(String enteredCode) {
    if (_currentCode == null || _codeGeneratedAt == null) {
      return VerificationResult.expired;
    }

    if (DateTime.now().difference(_codeGeneratedAt!) > _codeExpiry) {
      _currentCode = null;
      _codeGeneratedAt = null;
      return VerificationResult.expired;
    }

    if (_attempts >= _maxAttempts) {
      return VerificationResult.tooManyAttempts;
    }

    _attempts++;

    if (enteredCode == _currentCode) {
      _currentCode = null;
      _codeGeneratedAt = null;
      _attempts = 0;
      return VerificationResult.success;
    }

    return VerificationResult.incorrect;
  }

  /// Whether the resend cooldown has passed.
  bool canResend(DateTime lastSentAt) {
    return DateTime.now().difference(lastSentAt) >= _resendCooldown;
  }

  /// Seconds remaining until the user can request a new code.
  int secondsUntilResend(DateTime lastSentAt) {
    final elapsed = DateTime.now().difference(lastSentAt);
    final remaining = _resendCooldown - elapsed;
    return remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  }

  /// Generates a unique Kora ID: KM-XXXXXXXXX (9 digits). e.g. KM-383196342
  String generateKoraId() {
    final rng = Random();
    final id = rng.nextInt(900000000) + 100000000;
    return 'KM-$id';
  }

  /// Masks an email for display: ijezie@gmail.com -> i***@gmail.com
  String maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 1) return email;
    final localPart = email.substring(0, atIndex);
    final domain = email.substring(atIndex);
    final visible = localPart.length >= 2 ? localPart.substring(0, 2) : localPart[0];
    return '$visible***$domain';
  }
}

/// Result of a verification attempt.
enum VerificationResult {
  success,
  incorrect,
  expired,
  tooManyAttempts,
  networkError,
}

/// Which flow triggered the verification screen.
enum VerificationType {
  registration,
  login,
  passwordReset,
}
