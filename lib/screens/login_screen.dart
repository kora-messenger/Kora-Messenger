import 'package:flutter/material.dart';
import '../config/kora_api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import '../services/settings_sync_service.dart';
import '../services/crash_logger.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import 'forgot_password_screen.dart';
import 'profile_setup_screen.dart';
import 'kora_home_screen.dart';
import 'login_verification_screen.dart';
import 'suspension_screen.dart';
import 'signup_screen.dart';
import 'backup_pin_login_screen.dart';
import 'passkey_login_screen.dart';
import '../services/device_manager.dart';
import '../services/accounts_manager.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kora Login screen — deep black surface, purple gradient accents.
/// User enters email + password to log in. New devices trigger verification.
class LogInScreen extends StatefulWidget {
  final bool isAddingAccount;
  const LogInScreen({super.key, this.isAddingAccount = false});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final AuthService _auth = AuthService.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _popupShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBackupPinPopup());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showBackupPinPopup() async {
    if (_popupShown || !mounted) return;
    _popupShown = true;

    // Check which alternative sign-in options exist
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('kora_last_email') ?? '';
    bool hasBackupPin = false;
    bool hasPasskey = false;

    if (lastEmail.isNotEmpty) {
      final options = await _auth.checkSignInOptions(email: lastEmail);
      hasBackupPin = options.hasBackupPin;
      hasPasskey = options.passkeysEnabled;
    }

    if (!mounted) return;

    // If neither option is available, don't show the popup
    if (!hasBackupPin && !hasPasskey) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A4E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alternative Sign-in',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a faster way to sign in to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            // Passkey option (if available)
            if (hasPasskey) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PasskeyLoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Use Passkey', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Backup PIN option (if available)
            if (hasBackupPin) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: hasPasskey
                  ? TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BackupPinLoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: KoraColors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: KoraColors.purple, width: 1),
                        ),
                      ),
                      child: const Text('Use Backup PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: KoraColors.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BackupPinLoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Use Backup PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address');
      return;
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.login(email: email, password: password);

      if (!mounted) return;

      if (result.needsDeviceVerification) {
        setState(() => _isLoading = false);
        TextInput.finishAutofillContext();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginVerificationScreen(
            email: email,
            deliveryMethod: result.deliveryMethod,
            nextType: result.nextType,
            timeout: result.timeout,
          )),
        );
        return;
      }

      if (result.success && result.user != null) {
        final user = KoraUserSession.fromMap(result.user!);

        // Check suspension status before allowing access
        try {
          final suspensionResp = await http.post(
            Uri.parse(KoraApi.autoDetectEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'checkSuspensionStatus',
              'email': email,
            }),
          ).timeout(const Duration(seconds: 15));
          final suspData = jsonDecode(suspensionResp.body);
          if (suspData['suspended'] == true && mounted) {
            setState(() => _isLoading = false);
            TextInput.finishAutofillContext();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => SuspensionScreen(
                  email: email,
                  suspensionReason: suspData['reason'] ?? 'Your account has been suspended for violating Kora Messenger Community Guidelines.',
                  isPermanent: suspData['isPermanent'] ?? false,
                  expiresAt: suspData['expiresAt'],
                  hoursRemaining: suspData['hoursRemaining'],
                  appealStatus: suspData['appealStatus'] ?? 'none',
                ),
              ),
              (route) => false,
            );
            return;
          }
        } catch (_) {
          // If suspension check fails, allow login (fail open)
        }
        // Fetch fresh profile from backend to ensure avatar URL and
        // other data persist across app reinstalls.
        try {
          final freshProfile = await _auth.getProfile(userId: result.user!['id'] ?? '');
          if (freshProfile.success && freshProfile.user != null) {
            await SessionManager.instance.saveSession(freshProfile.user!);
          } else {
            await SessionManager.instance.saveSession(result.user!);
          }
        } catch (_) {
          await SessionManager.instance.saveSession(result.user!);
        }
        await ChatThemeProvider.instance.load();
        // Sync premium from backend session
        final session = await SessionManager.instance.loadSession();
        if (session != null) {
          await ChatThemeProvider.instance.syncPremiumFromSession(session);
          if (session['email'] != null) {
            ChatSyncService.instance.setUserEmail(session['email'] as String);
            ChatSyncService.instance.setSenderName(
              (session?['fullName'] as String?) ?? '',
            );
          }
          // Register this account in the multi-account list.
          await AccountsManager.instance.addOrUpdateAccount(session);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kora_last_email', email);
        // Ensure persistent device ID is set (survives app reinstall)
        await DeviceManager.getDeviceId();
        await DeviceManager.getDeviceName();
        if (!mounted) return;

        TextInput.finishAutofillContext();

        // Show chat restore overlay for returning users, then navigate
        if (user.profileCompleted) {
          // Show restoring overlay while syncing chats in background
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
              (route) => false,
            );
            // Restore chats after navigation — overlay shows on home screen
            if (session != null && session['email'] != null) {
              ChatSyncService.instance.restoreFromCloud().then((_) {
                ChatSyncService.instance.startPolling();
                SettingsSyncService.instance.syncNow();
                SettingsSyncService.instance.startPeriodicSync();
              });
            }
          }
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ProfileSetupScreen(email: email, userData: result.user!),
            ),
            (route) => false,
          );
          if (session != null && session['email'] != null) {
            ChatSyncService.instance.startPolling();
          }
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'A network error occurred. Please check your connection and try again.';
          _isLoading = false;
        });
        print('[LoginScreen] login failed: success=\${result.success}, needsVerification=\${result.needsDeviceVerification}, error=\${result.error}');
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'LoginScreen._submit');
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: AppBar(
        backgroundColor: KoraColors.trueBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log in to continue to Kora.',
                style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1517),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              KoraInput(
                label: 'Email Address',
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.email_outlined, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              KoraInput(
                label: 'Password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              KoraButton(
                label: 'Log In',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(KoraApi.termsOfServiceUrl);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text(
                      'Terms',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Text(' · ', style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 12)),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(KoraApi.privacyPolicyUrl);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text(
                      'Privacy',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Text(' · ', style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 12)),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(KoraApi.gdprPrivacyPolicyUrl);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text(
                      'GDPR (EU)',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Text(' · ', style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 12)),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(KoraApi.e2eePolicyUrl);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text(
                      'E2EE',
                      style: TextStyle(color: KoraColors.purple, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
