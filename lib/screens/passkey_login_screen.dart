import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import '../services/crash_logger.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import 'kora_home_screen.dart';

/// Login using a Passkey — the user enters their email, then authenticates
/// with their device biometric/PIN. The backend verifies that a passkey
/// exists for this device + email combo.
class PasskeyLoginScreen extends StatefulWidget {
  const PasskeyLoginScreen({super.key});

  @override
  State<PasskeyLoginScreen> createState() => _PasskeyLoginScreenState();
}

class _PasskeyLoginScreenState extends State<PasskeyLoginScreen> {
  final _auth = AuthService.instance;
  final _localAuth = LocalAuthentication();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _isLoading = false;
  bool _authenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  Future<void> _loadLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('kora_last_email');
    if (lastEmail != null && lastEmail.isNotEmpty && mounted) {
      setState(() => _emailController.text = lastEmail);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check if passkeys are enabled for this account
    final options = await _auth.checkSignInOptions(email: email);
    if (!mounted) return;

    if (!options.passkeysEnabled) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Passkeys are not enabled for this account. Please use email and password.';
      });
      return;
    }

    // Trigger biometric authentication
    setState(() {
      _isLoading = false;
      _authenticating = true;
    });

    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!available) {
        setState(() {
          _authenticating = false;
          _errorMessage = 'Biometric authentication is not available on this device.';
        });
        return;
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in to Kora',
        biometricOnly: false,
      );

      if (!mounted) return;

      if (didAuth) {
        // Biometric succeeded → verify with backend
        final result = await _auth.loginWithPasskey(email: email);

        if (!mounted) return;

        if (result.success && result.user != null) {
          await SessionManager.instance.saveSession(result.user!);
          await ChatThemeProvider.instance.load();
        // Set user email for cloud chat sync
        final session = await SessionManager.instance.loadSession();
        if (session != null && session['email'] != null) {
          ChatSyncService.instance.setUserEmail(session['email'] as String);
        } // Refresh owner/premium status for badge + gating

          // Save last email
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('kora_last_email', email);

          if (!mounted) return;
          setState(() => _authenticating = false);

          // Navigate
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
            (route) => false,
          );
        } else {
          setState(() {
            _authenticating = false;
            _errorMessage = result.error ?? 'Passkey login failed. This device may not have a passkey for this account.';
          });
        }
      } else {
        setState(() {
          _authenticating = false;
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'PasskeyLoginScreen._continue');
      if (mounted) {
        setState(() {
          _authenticating = false;
          _errorMessage = 'Authentication error. Please try again.';
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
        title: const Text(
          'Sign in with Passkey',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter your email and authenticate with your device to sign in instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    KoraInput(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B6B80), size: 22),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: KoraColors.trueBlack,
                border: const Border(top: BorderSide(color: Color(0xFF2E2E42), width: 0.5)),
              ),
              child: _authenticating
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 3),
                      ),
                      const SizedBox(height: 12),
                      Text('Authenticating...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                    ],
                  )
                : KoraButton(
                    label: 'Continue',
                    isLoading: _isLoading,
                    onPressed: _continue,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
