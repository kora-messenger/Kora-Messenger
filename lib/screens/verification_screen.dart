import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_button.dart';
import '../services/auth_service.dart';
import 'profile_setup_screen.dart';
import 'kora_home_screen.dart';
import 'new_password_screen.dart';

/// Kora's unified verification-code screen.
///
/// Used for registration and password-reset flows.
/// Shows where the code was sent, provides 6-box code entry,
/// resend with countdown, and handles all verification states.
class VerificationScreen extends StatefulWidget {
  final VerificationType type;
  final String email;
  final Map<String, dynamic>? userData;

  const VerificationScreen({
    super.key,
    required this.type,
    required this.email,
    this.userData,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final AuthService _auth = AuthService.instance;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _countdownTimer;
  int _countdown = 60;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _title {
    switch (widget.type) {
      case VerificationType.registration:
        return 'Verify Your Email';
      case VerificationType.login:
        return 'Verify Your Account';
      case VerificationType.passwordReset:
        return 'Verify Your Email';
    }
  }

  String get _subtitle {
    switch (widget.type) {
      case VerificationType.registration:
        return "We've sent a verification code to your email address.";
      case VerificationType.login:
        return 'Enter the verification code we sent to your email.';
      case VerificationType.passwordReset:
        return "We've sent a verification code to reset your password.";
    }
  }

  String get _maskedEmail => _auth.maskEmail(widget.email);

  String get _enteredCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length < 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    if (widget.type == VerificationType.registration) {
      // Verify code + create account
      final result = await _auth.verifyAndSignUp(
        email: widget.email,
        code: _enteredCode,
        userData: Map<String, String>.from(widget.userData ?? {}),
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (result.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              email: (result.user?['email'] ?? widget.email) as String,
              userData: result.user ?? widget.userData ?? {},
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = result.error ?? 'Verification failed');
        _clearInputs();
      }
    } else if (widget.type == VerificationType.passwordReset) {
      // Go to NewPasswordScreen with the code
      setState(() => _isVerifying = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(
            email: widget.email,
            verificationCode: _enteredCode,
          ),
        ),
      );
    } else if (widget.type == VerificationType.login) {
      // Login flow (shouldn't normally reach here with new flow, but handle it)
      setState(() => _isVerifying = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final typeStr = widget.type == VerificationType.passwordReset
        ? 'passwordReset'
        : 'registration';
    final result = await _auth.sendVerificationCode(widget.email, type: typeStr);

    if (!mounted) return;

    if (result.success) {
      _clearInputs();
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent to your email.'),
          backgroundColor: KoraColors.darkCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _errorMessage = result.error ?? 'Failed to resend code');
    }

    setState(() => _isResending = false);
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _changeEmail() {
    Navigator.of(context).pop();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _subtitle,
                style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Code sent to $_maskedEmail',
                      style: const TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _changeEmail,
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              _buildCodeBoxes(),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              KoraButton(
                label: 'Verify',
                onPressed: _verify,
                isLoading: _isVerifying,
              ),
              const SizedBox(height: 24),

              _buildResendSection(),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Text(
                    'Codes expire in 10 minutes.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _controllers[index].text.isNotEmpty
                      ? KoraColors.purple
                      : const Color(0xFF2E2E42),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KoraColors.purple, width: 2),
              ),
              filled: true,
              fillColor: KoraColors.darkCard,
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _focusNodes[index + 1].requestFocus();
              }
              if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
    );
  }

  Widget _buildResendSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't get the code? ",
          style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
        ),
        if (_countdown > 0)
          Text(
            'Resend in ${_countdown}s',
            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 14),
          )
        else
          _isResending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KoraColors.purple,
                  ),
                )
              : GestureDetector(
                  onTap: _resend,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(
                      color: KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
      ],
    );
  }
}
