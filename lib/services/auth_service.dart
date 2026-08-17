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

  // ── Username system ────────────────────────────────────────

  /// Usernames reserved by Kora — cannot be claimed by users.
  static const List<String> reservedUsernames = [
    'admin', 'administrator', 'kora', 'koramessenger', 'koraofficial',
    'support', 'help', 'system', 'root', 'official', 'team', 'staff',
    'moderator', 'mod', 'settings', 'about', 'security', 'login',
    'register', 'signup', 'api', 'bot', 'null', 'undefined', 'test',
    'demo', 'info', 'contact', 'welcome', 'home', 'messenger',
    'founder', 'ceo', 'dev', 'developer', 'operator', 'service',
    'page', 'profile', 'account', 'user', 'me', 'my', 'all', 'new',
    'edit', 'delete', 'create', 'post', 'message', 'chat', 'group',
    'channel', 'broadcast', 'notification', 'verify', 'auth',
  ];

  /// Mock list of usernames already taken by other users.
  /// In production this would be a database query.
  static const List<String> _takenUsernames = [
    'john', 'jane', 'mike', 'sarah', 'david', 'emma', 'chris',
    'alex', 'sam', 'jordan', 'taylor', 'morgan', 'casey', 'riley',
    'jamie', 'goodluck', 'ijezie', 'kora_user', 'admin1', 'testuser',
    'user123', 'hello_world', 'flutter_dev', 'john_doe',
  ];

  /// Validates username format rules.
  /// Returns null if valid, error message if invalid.
  static String? validateUsernameFormat(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Must be at least 3 characters';
    if (username.length > 20) return 'Must be at most 20 characters';
    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) {
      return 'Must start with a letter';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Only letters, numbers, and underscores';
    }
    if (username.endsWith('_')) return 'Cannot end with an underscore';
    if (username.contains('__')) return 'No consecutive underscores';
    return null;
  }

  /// Checks username availability (format + reserved + taken).
  UsernameCheckResult checkUsername(String username) {
    // Format validation first
    final formatError = validateUsernameFormat(username);
    if (formatError != null) {
      if (username.length < 3) {
        return UsernameCheckResult(UsernameStatus.tooShort, formatError);
      }
      return UsernameCheckResult(UsernameStatus.invalid, formatError);
    }

    final lower = username.toLowerCase();

    // Reserved check
    if (reservedUsernames.contains(lower)) {
      return const UsernameCheckResult(UsernameStatus.reserved, 'This username is reserved');
    }

    // Taken check (mock)
    if (_takenUsernames.contains(lower)) {
      return const UsernameCheckResult(UsernameStatus.taken, 'This username is already taken');
    }

    return const UsernameCheckResult(UsernameStatus.available, 'Available');
  }

  // ── Verification codes ─────────────────────────────────────

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

/// Status of a username availability check.
enum UsernameStatus {
  idle,
  checking,
  available,
  taken,
  reserved,
  invalid,
  tooShort,
}

/// Result of checking a username.
class UsernameCheckResult {
  final UsernameStatus status;
  final String message;

  const UsernameCheckResult(this.status, this.message);
}
