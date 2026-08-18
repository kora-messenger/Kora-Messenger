import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_button.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'profile_setup_screen.dart';
import 'kora_home_screen.dart';
import 'new_password_screen.dart';

/// Kora's unified verification-code screen.
///
/// Used for registration and password-reset flows.
/// Auto-fills code from clipboard (only when the user returns from
/// their email app with a freshly-copied code) and auto-verifies
/// when all 6 digits are entered.
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

class _VerificationScreenState extends State<VerificationScreen>
    with WidgetsBindingObserver {
  final AuthService _auth = AuthService.instance;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _countdownTimer;
  int _countdown = 60;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _autoVerifying = false;

  /// Clipboard content when the screen first opened.
  /// We only auto-fill if the clipboard CHANGED since then (i.e. the
  /// user copied a new code from their email app).
  String? _initialClipboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
    // Record the clipboard state on screen open so we can detect
    // NEW clipboard content later (when user returns from email app).
    _snapshotClipboard();
  }

  Future<void> _snapshotClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      _initialClipboard = data?.text?.trim() ?? '';
    } catch (_) {
      _initialClipboard = '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  // ── Clipboard auto-fill ──────────────────────────────────
  Future<void> _checkClipboard() async {
    // Don't overwrite if user already typed something
    if (_enteredCode.length >= 6 || _autoVerifying) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';

      // Only auto-fill if the clipboard content CHANGED since the screen
      // opened — this prevents using stale codes and ensures the user
      // actually copied a fresh code from their email.
      if (text == _initialClipboard) return;

      // Look for a 6-digit code in the clipboard text
      final match = RegExp(r'(\d{6})').firstMatch(text);
      if (match != null) {
        final code = match.group(1)!;
        _fillCode(code);
      }
    } catch (_) {
      // Silently ignore clipboard errors
    }
  }

  void _fillCode(String code) {
    final sixDigits = code.replaceAll(RegExp(r'[^\d]'), '');
    if (sixDigits.length < 6) return;

    for (int i = 0; i < 6; i++) {
      _controllers[i].text = sixDigits[i];
    }
    _focusNodes[5].unfocus();
    setState(() {});

    // Auto-verify after filling
    _triggerAutoVerify();
  }

  void _triggerAutoVerify() {
    if (_enteredCode.length == 6 && !_autoVerifying && !_isVerifying) {
      _autoVerifying = true;
      _verify();
    }
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
      _autoVerifying = false;
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    if (widget.type == VerificationType.registration) {
      final result = await _auth.verifyAndSignUp(
        email: widget.email,
        code: _enteredCode,
        userData: Map<String, String>.from(widget.userData ?? {}),
      );

      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _autoVerifying = false;
      });

      if (result.success) {
        // Merge backend response with the original signup data so we
        // don't lose fields like fullName that the backend might not echo back.
        final mergedUser = <String, dynamic>{
          ...?widget.userData,
          ...?result.user,
        };
        // If backend returned empty fullName, fall back to the signup value.
        if ((mergedUser['fullName'] ?? '').isEmpty) {
          mergedUser['fullName'] = widget.userData?['fullName'] ?? '';
        }
        await SessionManager.instance.saveSession(mergedUser);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              email: (result.user?['email'] ?? widget.email) as String,
              userData: mergedUser,
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = result.error ?? 'Verification failed');
        _clearInputs();
      }
    } else if (widget.type == VerificationType.passwordReset) {
      // Verify the code against the backend before proceeding.
      final verifyResult = await _auth.verifyCode(
        email: widget.email,
        code: _enteredCode,
        type: 'passwordReset',
      );

      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _autoVerifying = false;
      });

      if (verifyResult.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(
              email: widget.email,
              verificationCode: _enteredCode,
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = verifyResult.error ?? 'Invalid verification code');
        _clearInputs();
      }
    } else if (widget.type == VerificationType.login) {
      setState(() {
        _isVerifying = false;
        _autoVerifying = false;
      });
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
        : widget.type == VerificationType.login
            ? 'login'
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
    _autoVerifying = false;
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

              // Verify button (fallback — auto-verify fires first when code is complete)
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
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12),
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
          child: KeyboardListener(
            focusNode: _focusNodes[index],
            onKeyEvent: (event) {
              // Detect backspace on an EMPTY box — move focus to the
              // previous box and clear it so the user can keep deleting
              // backwards in one fluid motion.
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                if (_controllers[index].text.isEmpty && index > 0) {
                  _controllers[index - 1].clear();
                  _focusNodes[index - 1].requestFocus();
                  setState(() {});
                }
              }
            },
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
                // Handle paste of multi-character text
                if (value.length > 1) {
                  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length >= 6) {
                    _fillCode(digits.substring(0, 6));
                    return;
                  }
                  // Partial paste — fill what we can
                  for (int i = 0; i < digits.length && (index + i) < 6; i++) {
                    _controllers[index + i].text = digits[i];
                  }
                  if (index + digits.length < 6) {
                    _focusNodes[index + digits.length].requestFocus();
                  }
                  setState(() {});
                  if (_enteredCode.length == 6) {
                    _triggerAutoVerify();
                  }
                  return;
                }

                // Normal single-character input
                if (value.isNotEmpty && index < 5) {
                  _focusNodes[index + 1].requestFocus();
                }
                setState(() {});

                // Auto-verify when all 6 digits filled
                if (_enteredCode.length == 6) {
                  _triggerAutoVerify();
                }
              },
            ),
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
