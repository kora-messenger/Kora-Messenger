import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../services/auth_service.dart';
import '../services/crash_logger.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import 'verification_screen.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/kora_api.dart';

/// Kora Sign-up screen — deep black surface, purple gradient accents.
///
/// Fields: full name, username (with live availability check), email,
/// password, confirm password. Phone number is intentionally omitted
/// for now — it will be added back in a later release.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  final AuthService _auth = AuthService.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _agreedToTerms = false;

  // Username live-check
  UsernameStatus _usernameStatus = UsernameStatus.idle;
  String _usernameMessage = '';
  Timer? _usernameTimer;

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ── Username live availability ───────────────────────────

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    final trimmed = value.trim();

    setState(() {
      if (trimmed.isEmpty) {
        _usernameStatus = UsernameStatus.idle;
        _usernameMessage = '';
      } else if (trimmed.length < 3) {
        _usernameStatus = UsernameStatus.tooShort;
        _usernameMessage = 'Too short';
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
        _usernameStatus = UsernameStatus.invalid;
        _usernameMessage = 'Only letters, numbers, underscores';
      } else {
        _usernameStatus = UsernameStatus.checking;
        _usernameMessage = 'Checking...';
        _usernameTimer = Timer(const Duration(milliseconds: 500), () {
          _checkUsernameAvailability(trimmed);
        });
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final result = await _auth.checkUsername(username);
    if (!mounted) return;
    setState(() {
      _usernameStatus = result.status;
      _usernameMessage = result.message;
    });
  }

  Color get _usernameAccentColor {
    switch (_usernameStatus) {
      case UsernameStatus.available:
        return const Color(0xFF22C55E);
      case UsernameStatus.taken:
      case UsernameStatus.reserved:
      case UsernameStatus.invalid:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B6B80);
    }
  }

  IconData get _usernameTrailingIcon {
    switch (_usernameStatus) {
      case UsernameStatus.available:
        return Icons.check_circle;
      case UsernameStatus.taken:
      case UsernameStatus.reserved:
      case UsernameStatus.invalid:
        return Icons.cancel;
      case UsernameStatus.checking:
        return Icons.hourglass_top;
      default:
        return Icons.alternate_email;
    }
  }

  // ── Legal links ─────────────────────────────────────────

  Future<void> _launchLegalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore — non-critical.
    }
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLoading) return;

    // Read directly from controllers to avoid any Form/state sync issues.
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() => _errorMessage = null);

    String? error;

    if (name.isEmpty) {
      error = 'Enter your name to continue.';
    } else if (name.length < 2) {
      error = 'Name must be at least 2 characters';
    } else if (username.isEmpty) {
      error = 'Please enter a username';
    } else if (username.length < 3) {
      error = 'Username must be at least 3 characters';
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      error = 'Username: only letters, numbers and underscores';
    } else if (email.isEmpty) {
      error = 'Enter your email address';
    } else if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      error = 'Please enter a valid email address.';
    } else if (password.isEmpty) {
      error = 'Please enter a password';
    } else if (password.length < 8) {
      error = 'Password must be at least 8 characters';
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      error = 'Password must include at least one uppercase letter';
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      error = 'Password must include at least one number';
    } else if (confirmPassword.isEmpty) {
      error = 'Please confirm your password';
    } else if (confirmPassword != password) {
      error = 'Passwords do not match';
    } else if (!_agreedToTerms) {
      error = 'Please agree to the Terms, Privacy Policy, EULA, and E2EE Disclosure';
    }

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    // Give an in-flight username check a moment to resolve.
    if (_usernameStatus == UsernameStatus.checking) {
      setState(() => _isLoading = true);
      int waited = 0;
      while (_usernameStatus == UsernameStatus.checking && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
      }
    }

    if (_usernameStatus == UsernameStatus.taken ||
        _usernameStatus == UsernameStatus.reserved) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please choose an available username';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.sendVerificationCode(email, type: 'registration');

      if (!mounted) return;

      if (result.success) {
        // Close any pending Android autofill session (e.g. the native
        // "Save password?" prompt) before navigating away — leaving it
        // open while the password field's view is torn down is a known
        // native crash.
        TextInput.finishAutofillContext();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              type: VerificationType.registration,
              email: email,
              userData: {
                'fullName': name,
                'username': username,
                'email': email,
                'password': password,
              },
            ),
          ),
        );
      } else {
        final errorMsg = result.error ?? 'Failed to send verification code';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'SignUpScreen._submit');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Build ───────────────────────────────────────────────

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

              const Text(
                'Create your account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join Kora and start connecting today.',
                style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
              ),
              const SizedBox(height: 24),

              // Full name
              KoraInput(
                label: 'Full name',
                controller: _nameController,
                focusNode: _nameFocus,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.person_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              // Username (validated manually + live-checked against backend)
              KoraInput(
                label: 'Username',
                controller: _usernameController,
                focusNode: _usernameFocus,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(_usernameTrailingIcon, color: _usernameAccentColor, size: 22),
                ),
                suffixIcon: _usernameStatus == UsernameStatus.checking
                    ? const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
                        ),
                      )
                    : null,
                onChanged: _onUsernameChanged,
              ),
              if (_usernameStatus != UsernameStatus.idle)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _usernameMessage,
                    style: TextStyle(
                      color: _usernameAccentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Email
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

              // Password
              KoraInput(
                label: 'Create password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password
              KoraInput(
                label: 'Confirm password',
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocus,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 20),

              _buildTermsCheckbox(),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
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
                const SizedBox(height: 16),
              ],

              KoraButton(
                label: 'Create Account',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LogInScreen()),
                      );
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          activeColor: KoraColors.purple,
          checkColor: Colors.white,
          side: const BorderSide(color: Color(0xFF6B6B80), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'I agree to the ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _launchLegalUrl(KoraApi.termsOfServiceUrl),
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  ', ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _launchLegalUrl(KoraApi.privacyPolicyUrl),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  ', ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _launchLegalUrl(KoraApi.eulaUrl),
                  child: const Text(
                    'EULA',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  ', and ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _launchLegalUrl(KoraApi.e2eePolicyUrl),
                  child: const Text(
                    'E2EE Disclosure',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  '. EU users: see our ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => _launchLegalUrl(KoraApi.gdprPrivacyPolicyUrl),
                  child: const Text(
                    'GDPR Privacy Policy',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
