import 'dart:convert';
import 'package:http/http.dart' as http;
import 'device_manager.dart';
import '../config/kora_api.dart';

/// Real authentication service for Kora Messenger.
/// Calls the backend API for all auth operations.
///
/// Config is centralized in lib/config/kora_api.dart.
/// When you get your domain, just change the baseUrl there.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const String _endpoint = KoraApi.authEndpoint;

  // ── Username validation (client-side) ──────────────────────

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

  /// Checks username availability against the backend.
  /// Returns a UsernameCheckResult.
  Future<UsernameCheckResult> checkUsername(String username) async {
    final formatError = validateUsernameFormat(username);
    if (formatError != null) {
      if (username.length < 3) {
        return UsernameCheckResult(UsernameStatus.tooShort, formatError);
      }
      return UsernameCheckResult(UsernameStatus.invalid, formatError);
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'checkUsername', 'username': username}),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true && data['available'] == true) {
        return const UsernameCheckResult(UsernameStatus.available, 'Available');
      } else if (data['available'] == false) {
        final reason = data['reason'] as String? ?? 'Username unavailable';
        if (reason.toLowerCase().contains('reserved')) {
          return UsernameCheckResult(UsernameStatus.reserved, reason);
        }
        return UsernameCheckResult(UsernameStatus.taken, reason);
      }
      return UsernameCheckResult(UsernameStatus.invalid, data['error'] ?? 'Check failed');
    } catch (e) {
      return const UsernameCheckResult(UsernameStatus.invalid, 'Network error');
    }
  }

  // ── Send verification code ──────────────────────────────────

  /// Sends a verification code to the given email.
  /// Returns (success, errorMessage).
  Future<({bool success, String? error})> sendVerificationCode(
    String email, {
    String type = 'registration',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'sendCode',
          'email': email,
          'type': type,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: 'Network error. Check your connection.');
    }
  }

  // ── Verify code and sign up ──────────────────────────────────

  /// Verifies the code and creates the account.
  /// Returns (success, errorMessage, userData).
  Future<({bool success, String? error, Map<String, dynamic>? user})>
      verifyAndSignUp({
    required String email,
    required String code,
    required Map<String, String> userData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyAndSignUp',
          'email': email,
          'code': code,
          'userData': userData,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (
        success: false,
        error: 'Network error. Check your connection.',
        user: null,
      );
    }
  }

  // ── Login ────────────────────────────────────────────────────

  /// Logs in with email and password (with device recognition).
  ///
  /// Returns:
  /// - success=true, user=... → device recognized, auto-login
  /// - needsDeviceVerification=true → new device, code sent to email
  /// - success=false, error=... → wrong credentials or error
  Future<({
    bool success,
    bool needsDeviceVerification,
    String? error,
    Map<String, dynamic>? user,
  })> login({
    required String email,
    required String password,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      final deviceName = await DeviceManager.getDeviceName();
      final platform = DeviceManager.getPlatform();

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'email': email,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          needsDeviceVerification: false,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }

      if (data['needsDeviceVerification'] == true) {
        return (
          success: false,
          needsDeviceVerification: true,
          error: null,
          user: null,
        );
      }

      return (
        success: false,
        needsDeviceVerification: false,
        error: data['error'] as String?,
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        needsDeviceVerification: false,
        error: 'Network error. Check your connection.',
        user: null,
      );
    }
  }

  /// Verifies a login code from a new device.
  /// If [recognizeDevice] is true, the device is saved as trusted.
  ///
  /// Returns (success, errorMessage, userData).
  Future<({
    bool success,
    String? error,
    Map<String, dynamic>? user,
  })> verifyLogin({
    required String email,
    required String code,
    bool recognizeDevice = true,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      final deviceName = await DeviceManager.getDeviceName();
      final platform = DeviceManager.getPlatform();

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyLogin',
          'email': email,
          'code': code,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
          'recognizeDevice': recognizeDevice,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (
        success: false,
        error: 'Network error. Check your connection.',
        user: null,
      );
    }
  }

  // ── Verify code and reset password ──────────────────────────

  /// Verifies the code and resets the password.
  /// Verifies a code without performing any other action.
  /// Used to validate the code before showing the next screen.
  Future<({bool success, String? error})> verifyCode({
    required String email,
    required String code,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyCode',
          'email': email,
          'code': code,
          'type': type,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: 'Network error. Check your connection.');
    }
  }

  Future<({bool success, String? error})> verifyAndResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyAndResetPassword',
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: 'Network error. Check your connection.');
    }
  }

  // ── Save profile ───────────────────────────────────────────

  /// Saves the user's profile data (name, username, bio, avatar).
  /// Returns (success, errorMessage, userData).
  Future<({bool success, String? error, Map<String, dynamic>? user})>
      saveProfile({
    required String userId,
    required String fullName,
    required String username,
    String bio = '',
    String avatarUrl = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'saveProfile',
          'userId': userId,
          'fullName': fullName,
          'username': username,
          'bio': bio,
          'avatarUrl': avatarUrl,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (
        success: false,
        error: 'Network error. Check your connection.',
        user: null,
      );
    }
  }

  // ── Utility ──────────────────────────────────────────────────

  /// Generates a unique Kora ID: KM-XXXXXXXXX (9 digits).
  String generateKoraId() {
    final rng = DateTime.now().millisecondsSinceEpoch;
    final id = (rng % 900000000) + 100000000;
    return 'KM-$id';
  }

  /// Masks an email for display: ijezie@gmail.com -> i***@gmail.com
  String maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 1) return email;
    final localPart = email.substring(0, atIndex);
    final domain = email.substring(atIndex);
    final visible =
        localPart.length >= 2 ? localPart.substring(0, 2) : localPart[0];
    return '$visible***$domain';
  }
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

/// Logged-in user session data.
class KoraUserSession {
  final String id;
  final String email;
  final String username;
  final String koraId;
  final String fullName;
  final String bio;
  final String avatarUrl;
  final bool profileCompleted;

  KoraUserSession({
    required this.id,
    required this.email,
    required this.username,
    required this.koraId,
    required this.fullName,
    this.bio = '',
    this.avatarUrl = '',
    this.profileCompleted = false,
  });

  factory KoraUserSession.fromMap(Map<String, dynamic> map) {
    return KoraUserSession(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      koraId: map['koraId']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      avatarUrl: map['avatarUrl']?.toString() ?? '',
      profileCompleted: map['profileCompleted'] == true,
    );
  }
}
