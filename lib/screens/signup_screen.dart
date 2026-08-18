import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../services/auth_service.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import 'verification_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _auth = AuthService.instance;
  bool _isLoading = false;
  String? _errorMessage;
  bool _agreedToTerms = false;

  // Username live-check state
  UsernameStatus _usernameStatus = UsernameStatus.idle;
  String _usernameMessage = '';
  Timer? _usernameTimer;

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter a username';
    if (value.trim().length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers and underscores allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    // Phone is optional — only validate if user entered something
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(cleaned)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Username live availability check ─────────────────────
  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();

    setState(() {
      if (value.isEmpty) {
        _usernameStatus = UsernameStatus.idle;
        _usernameMessage = '';
      } else if (value.length < 3) {
        _usernameStatus = UsernameStatus.tooShort;
        _usernameMessage = 'Too short';
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
        _usernameStatus = UsernameStatus.invalid;
        _usernameMessage = 'Only letters, numbers, underscores';
      } else {
        _usernameStatus = UsernameStatus.checking;
        _usernameMessage = 'Checking...';
        _usernameTimer = Timer(const Duration(milliseconds: 500), () {
          _checkUsernameAvailability(value);
        });
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final result = await _auth.checkUsername(username);
    if (mounted) {
      setState(() {
        _usernameStatus = result.status;
        _usernameMessage = result.message;
      });
    }
  }

  Color get _usernameBorderColor {
    switch (_usernameStatus) {
      case UsernameStatus.available:
        return const Color(0xFF22C55E);
      case UsernameStatus.taken:
      case UsernameStatus.reserved:
      case UsernameStatus.invalid:
        return const Color(0xFFEF4444);
      case UsernameStatus.checking:
      case UsernameStatus.tooShort:
      case UsernameStatus.idle:
        return const Color(0xFF2E2E42);
    }
  }

  Color get _usernameIconColor {
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

  void _showComingSoon(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KoraColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '$title is coming soon. Stay tuned!',
          style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Block if user hasn't agreed to terms
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to the Terms of Service and Privacy Policy');
      return;
    }

    // If username is still checking, wait for it to finish (max 5s)
    if (_usernameStatus == UsernameStatus.checking) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      int waited = 0;
      while (_usernameStatus == UsernameStatus.checking && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
      }
    }

    // Block only on definitive "not available" statuses
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
    // If username check failed (invalid/network), don't block —
    // the backend will reject if truly taken. Let the user proceed.

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Send verification code via backend
    final result = await _auth.sendVerificationCode(
      _emailController.text.trim(),
      type: 'registration',
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            type: VerificationType.registration,
            email: _emailController.text.trim(),
            userData: {
              'fullName': _nameController.text.trim(),
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'phoneNumber': _phoneController.text.trim(),
              'password': _passwordController.text,
            },
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Failed to send verification code';
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
              const SizedBox(height: 24),

              // Full name
              KoraInput(
                label: 'Full name',
                controller: _nameController,
                keyboardType: TextInputType.name,
                validator: _validateName,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.person_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              // Username with live availability check
              KoraInput(
                label: 'Username',
                controller: _usernameController,
                keyboardType: TextInputType.text,
                validator: _validateUsername,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(_usernameTrailingIcon, color: _usernameIconColor, size: 22),
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
              // Username status message
              if (_usernameStatus != UsernameStatus.idle)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _usernameMessage,
                    style: TextStyle(
                      color: _usernameBorderColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Email (required)
              KoraInput(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.email_outlined, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              // Phone number (optional)
              KoraInput(
                label: 'Phone number (optional)',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.phone_outlined, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              KoraInput(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                validator: _validatePassword,
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
                obscureText: true,
                validator: _validateConfirmPassword,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 20),

              // Terms of Service checkbox
              _buildTermsCheckbox(),
              const SizedBox(height: 24),

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
                        MaterialPageRoute(
                          builder: (_) => const LogInScreen(),
                        ),
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
                  onTap: () => _showComingSoon('Terms of Service'),
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(
                  ' and ',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => _showComingSoon('Privacy Policy'),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: KoraColors.trueBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
