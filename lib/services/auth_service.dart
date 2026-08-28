import 'dart:async';
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

  /// Returns a user-friendly message for a caught exception,
  /// distinguishing a timeout (server too slow / unreachable) from
  /// other network errors so the UI never just hangs silently.
  static String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    }
    return 'Network error. Check your connection and try again.';
  }

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
      ).timeout(const Duration(seconds: 15));
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
      return UsernameCheckResult(UsernameStatus.invalid, _friendlyError(e));
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
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
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
      ).timeout(const Duration(seconds: 15));
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
        error: _friendlyError(e),
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
          'email': email.toLowerCase().trim(),
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));

      // Debug: log raw response for troubleshooting
      print('[AuthService] login response: ${response.statusCode} ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      // Try to parse the JSON body FIRST, even on non-200 — the backend's
      // error handler still returns a meaningful {success:false, error:...}
      // body on 4xx/5xx. Only fall back to a raw status-code message if the
      // body genuinely isn't parseable JSON (e.g. a proxy/HTML error page).
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return (
          success: false,
          needsDeviceVerification: false,
          error: response.statusCode == 200
              ? 'Unexpected response from server. Please try again.'
              : 'Server error (${response.statusCode}). Please try again.',
          user: null,
        );
      }

      // Handle success — check both boolean true and string 'true'
      final isSuccess = data['success'] == true || data['success'] == 'true';
      if (isSuccess) {
        final user = data['user'] as Map<String, dynamic>?;
        if (user == null) {
          return (
            success: false,
            needsDeviceVerification: false,
            error: 'Login succeeded but user data was missing. Please try again.',
            user: null,
          );
        }
        return (
          success: true,
          needsDeviceVerification: false,
          error: null,
          user: user,
        );
      }

      // Handle device verification — check both boolean true and string 'true'
      final needsVerification = data['needsDeviceVerification'] == true || data['needsDeviceVerification'] == 'true';
      if (needsVerification) {
        return (
          success: false,
          needsDeviceVerification: true,
          error: null,
          user: null,
        );
      }

      // Return the backend's error message, or a specific fallback
      final backendError = data['error'] as String?;
      return (
        success: false,
        needsDeviceVerification: false,
        error: backendError ?? 'Unable to login. Please check your details and try again.',
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        needsDeviceVerification: false,
        error: _friendlyError(e),
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
      ).timeout(const Duration(seconds: 15));
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
        error: _friendlyError(e),
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
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
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
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
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
      ).timeout(const Duration(seconds: 15));
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
        error: _friendlyError(e),
        user: null,
      );
    }
  }

  // ── Get Profile ───────────────────────────────────────────

  /// Fetches the latest profile data from the backend.
  /// Called on app startup and login to ensure the local session
  /// has the most up-to-date avatar URL, name, bio, etc.
  /// This ensures profile data survives app reinstall.
  Future<({bool success, String? error, Map<String, dynamic>? user})>
      getProfile({required String userId}) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'getProfile',
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 15));
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
      return (success: false, error: _friendlyError(e), user: null);
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

  // ── Save backup PIN ────────────────────────────────────────

  /// Saves the backup PIN to the user's account on the backend.
  /// The PIN is hashed server-side (SHA-256) — we send the raw PIN over HTTPS.
  Future<({bool success, String? error})> saveBackupPin({
    required String email,
    required String pin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'saveBackupPin',
          'email': email,
          'pin': pin,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null);
      }
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  // ── Login with backup PIN ──────────────────────────────────

  /// Logs in using email + backup PIN (bypasses password + device verification).
  /// The PIN is verified server-side against the stored hash.
  Future<({
    bool success,
    String? error,
    Map<String, dynamic>? user,
  })> loginWithBackupPin({
    required String email,
    required String pin,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      final deviceName = await DeviceManager.getDeviceName();
      final platform = DeviceManager.getPlatform();

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'loginWithBackupPin',
          'email': email,
          'pin': pin,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }
      return (
        success: false,
        error: data['error'] as String?,
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        error: _friendlyError(e),
        user: null,
      );
    }
  }

  // ── Save phone number (optional, onboarding) ────────────────

  Future<({bool success, String? error, Map<String, dynamic>? user})> savePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'savePhoneNumber',
          'userId': userId,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null, user: data['user'] as Map<String, dynamic>?);
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (success: false, error: _friendlyError(e), user: null);
    }
  }

  // ── Email change flow (two-step verification) ────────────────
  // All three methods call the dedicated koraEmailChange backend
  // function, not the main koraAuth endpoint.

  static const String _emailChangeEndpoint = KoraApi.emailChangeEndpoint;

  /// Step 1: Initiates email change by sending a verification code
  /// to the user's CURRENT (old) email address.
  Future<({bool success, String? error})> initiateEmailChange({
    required String userId,
    required String oldEmail,
    required String newEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailChangeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'initiateEmailChange',
          'userId': userId,
          'oldEmail': oldEmail,
          'newEmail': newEmail,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['success'] == true) return (success: true, error: null);
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  /// Step 2: Verifies the code sent to the old email, then the
  /// backend sends a new code to the new email address.
  Future<({bool success, String? error})> verifyOldEmailForChange({
    required String oldEmail,
    required String newEmail,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailChangeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyOldEmailForChange',
          'oldEmail': oldEmail,
          'newEmail': newEmail,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['success'] == true) return (success: true, error: null);
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  /// Step 3: Verifies the code sent to the new email and updates
  /// the account's email address. A security alert is sent to the
  /// old email by the backend.
  Future<({bool success, String? error, Map<String, dynamic>? user})> verifyAndUpdateEmail({
    required String userId,
    required String newEmail,
    required String oldEmail,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailChangeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verifyAndUpdateEmail',
          'userId': userId,
          'newEmail': newEmail,
          'oldEmail': oldEmail,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return (success: true, error: null, user: data['user'] as Map<String, dynamic>?);
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (success: false, error: _friendlyError(e), user: null);
    }
  }

  /// Resends the email change verification code.
  Future<({bool success, String? error})> resendEmailChangeCode({
    required String email,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailChangeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'resendEmailChangeCode',
          'email': email,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['success'] == true) return (success: true, error: null);
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  // ── Passkeys ─────────────────────────────────────────────────

  /// Turns the Passkeys feature on/off for the account.
  Future<({bool success, String? error})> setPasskeysEnabled({
    required String email,
    required bool enabled,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'setPasskeysEnabled',
          'email': email,
          'enabled': enabled,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) return (success: true, error: null);
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  /// Registers this device as a Passkey for the account. Call this only
  /// after the device's biometric/PIN prompt has already succeeded.
  Future<({bool success, String? error, Map<String, dynamic>? passkey})> createPasskey({
    required String email,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      final deviceName = await DeviceManager.getDeviceName();
      final platform = DeviceManager.getPlatform();

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'createPasskey',
          'email': email,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null, passkey: data['passkey'] as Map<String, dynamic>?);
      }
      return (success: false, error: data['error'] as String?, passkey: null);
    } catch (e) {
      return (success: false, error: _friendlyError(e), passkey: null);
    }
  }

  /// Lists all passkeys registered on the account (across devices).
  Future<({bool success, String? error, List<Map<String, dynamic>> passkeys})> listPasskeys({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'listPasskeys', 'email': email}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final list = (data['passkeys'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return (success: true, error: null, passkeys: list);
      }
      return (success: false, error: data['error'] as String?, passkeys: <Map<String, dynamic>>[]);
    } catch (e) {
      return (success: false, error: _friendlyError(e), passkeys: <Map<String, dynamic>>[]);
    }
  }

  /// Deletes a passkey by its record ID.
  Future<({bool success, String? error})> deletePasskey({
    required String email,
    required String passkeyId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'deletePasskey', 'email': email, 'passkeyId': passkeyId}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) return (success: true, error: null);
      return (success: false, error: data['error'] as String?);
    } catch (e) {
      return (success: false, error: _friendlyError(e));
    }
  }

  /// Logs in using this device's Passkey (biometric/PIN already verified
  /// on-device before calling this).
  Future<({bool success, String? error, Map<String, dynamic>? user})> loginWithPasskey({
    required String email,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      final deviceName = await DeviceManager.getDeviceName();
      final platform = DeviceManager.getPlatform();

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'loginWithPasskey',
          'email': email,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (success: true, error: null, user: data['user'] as Map<String, dynamic>?);
      }
      return (success: false, error: data['error'] as String?, user: null);
    } catch (e) {
      return (success: false, error: _friendlyError(e), user: null);
    }
  }

  /// Checks which alternative sign-in methods (backup PIN / passkeys)
  /// are available for an account, so the login screen can show the
  /// right options.
  Future<({bool success, bool hasBackupPin, bool passkeysEnabled})> checkSignInOptions({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'checkSignInOptions', 'email': email}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          hasBackupPin: data['hasBackupPin'] == true,
          passkeysEnabled: data['passkeysEnabled'] == true,
        );
      }
      return (success: false, hasBackupPin: false, passkeysEnabled: false);
    } catch (e) {
      return (success: false, hasBackupPin: false, passkeysEnabled: false);
    }
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
