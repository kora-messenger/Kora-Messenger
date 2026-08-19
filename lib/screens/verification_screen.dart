import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/crash_logger.dart';
import 'profile_setup_screen.dart';
import 'kora_home_screen.dart';
import 'new_password_screen.dart';

/// Kora's unified 6-digit verification-code screen.
///
/// Used for the registration and password-reset flows. Behavior
/// contract (per Kora's design rules):
///   • No submit button — verification fires automatically the instant
///     the 6th digit is entered.
///   • The code auto-fills from the clipboard when a fresh 6-digit
///     code is detected there (e.g. the user copied it from their
///     email app and returned to Kora).
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
  static const int _codeLength = 6;
  static const int _resendCooldownSeconds = 60;
  static const Duration _clipboardPollInterval = Duration(milliseconds: 1500);

  final AuthService _auth = AuthService.instance;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  Timer? _countdownTimer;
  Timer? _clipboardTimer;
  int _countdown = _resendCooldownSeconds;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;

  /// Guards against firing verification twice (e.g. clipboard fill +
  /// manual typing landing on the 6th digit around the same time).
  bool _verifyTriggered = false;

  /// Clipboard snapshot taken when this screen opened. We only treat
  /// clipboard content as a "fresh code to auto-fill" once it differs
  /// from this snapshot — otherwise a stale code sitting in the
  /// clipboard from before would get grabbed immediately on open.
  String _initialClipboard = '';

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
    WidgetsBinding.instance.addObserver(this);
    _startResendCountdown();
    _snapshotClipboard();
    _clipboardTimer = Timer.periodic(_clipboardPollInterval, (_) => _checkClipboard());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _clipboardTimer?.cancel();
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
    // Catches the common case: user leaves Kora to copy the code from
    // their email app, then comes back.
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  // ── Clipboard auto-fill ──────────────────────────────────────

  Future<void> _snapshotClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      _initialClipboard = data?.text?.trim() ?? '';
    } catch (_) {
      _initialClipboard = '';
    }
  }

  Future<void> _checkClipboard() async {
    if (!mounted || _enteredCode.length == _codeLength || _isVerifying) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _initialClipboard) return;

      final match = RegExp(r'(\d{6})').firstMatch(text);
      if (match == null) return;

      // Mark this clipboard content as "seen" so we don't refill on
      // the next poll tick with the exact same value.
      _initialClipboard = text;
      _fillCode(match.group(1)!);
    } catch (_) {
      // Clipboard access can fail on some platforms/permissions — ignore.
    }
  }

  void _setupFocusNodeKeyHandlers() {
    for (int i = 0; i < _codeLength; i++) {
      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty) {
          _onBackspaceOnEmptyBox(i);
        }
        return KeyEventResult.ignored;
      };
    }
  }

  // ── Code entry ────────────────────────────────────────────────

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _fillCode(String digits) {
    final clean = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < _codeLength || !mounted) return;

    for (int i = 0; i < _codeLength; i++) {
      _controllers[i].text = clean[i];
    }
    _focusNodes[_codeLength - 1].unfocus();
    setState(() => _errorMessage = null);
    _maybeAutoVerify();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // A paste landed directly in one of the boxes.
      final digits = value.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length >= _codeLength) {
        _fillCode(digits.substring(0, _codeLength));
        return;
      }
      for (int i = 0; i < digits.length && (index + i) < _codeLength; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = index + digits.length;
      if (nextIndex < _codeLength) {
        _focusNodes[nextIndex].requestFocus();
      }
      setState(() {});
      _maybeAutoVerify();
      return;
    }

    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
    _maybeAutoVerify();
  }

  void _onBackspaceOnEmptyBox(int index) {
    if (index == 0) return;
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    setState(() {});
  }

  void _maybeAutoVerify() {
    if (_enteredCode.length == _codeLength && !_verifyTriggered && !_isVerifying) {
      _verifyTriggered = true;
      _verify();
    }
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _verifyTriggered = false;
    if (mounted) setState(() {});
    _focusNodes[0].requestFocus();
  }

  // ── Verification ──────────────────────────────────────────────

  Future<void> _verify() async {
    if (_enteredCode.length < _codeLength) {
      _verifyTriggered = false;
      return;
    }

    _clipboardTimer?.cancel();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      switch (widget.type) {
        case VerificationType.registration:
          await _handleRegistrationVerify();
          break;
        case VerificationType.passwordReset:
          await _handlePasswordResetVerify();
          break;
        case VerificationType.login:
          await _handleLoginVerify();
          break;
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'VerificationScreen._verify');
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
      _clearInputs();
    }
  }

  Future<void> _handleRegistrationVerify() async {
    final result = await _auth.verifyAndSignUp(
      email: widget.email,
      code: _enteredCode,
      userData: Map<String, String>.from(widget.userData ?? {}),
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.success) {
      // Merge backend response with the original signup data so we
      // don't lose fields (like fullName) the backend might not echo back.
      final mergedUser = <String, dynamic>{
        ...?widget.userData,
        ...?result.user,
      };
      if ((mergedUser['fullName'] ?? '').toString().isEmpty) {
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
  }

  Future<void> _handlePasswordResetVerify() async {
    final result = await _auth.verifyCode(
      email: widget.email,
      code: _enteredCode,
      type: 'passwordReset',
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(
            email: widget.email,
            verificationCode: _enteredCode,
          ),
        ),
      );
    } else {
      setState(() => _errorMessage = result.error ?? 'Invalid verification code');
      _clearInputs();
    }
  }

  Future<void> _handleLoginVerify() async {
    // Actual device-verification API call happens upstream (login flow);
    // this branch just completes the visual step and lands on Home.
    if (!mounted) return;
    setState(() => _isVerifying = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
      (route) => false,
    );
  }

  // ── Resend ──────────────────────────────────────────────────────

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    _countdown = _resendCooldownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _resend() async {
    if (_countdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final typeStr = switch (widget.type) {
      VerificationType.passwordReset => 'passwordReset',
      VerificationType.login => 'login',
      VerificationType.registration => 'registration',
    };

    try {
      final result = await _auth.sendVerificationCode(widget.email, type: typeStr);
      if (!mounted) return;

      if (result.success) {
        _clearInputs();
        _startResendCountdown();
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
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'VerificationScreen._resend');
      if (mounted) setState(() => _errorMessage = 'Failed to resend code');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _changeEmail() => Navigator.of(context).pop();

  // ── Copy ──────────────────────────────────────────────────────

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

  // ── UI ────────────────────────────────────────────────────────

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
                      style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _changeEmail,
                    child: const Text(
                      'Change',
                      style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              _buildCodeBoxes(),
              const SizedBox(height: 16),
              if (_errorMessage != null) _buildErrorBanner(),
              if (_isVerifying) _buildVerifyingIndicator() else const SizedBox(height: 8),
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

  Widget _buildErrorBanner() {
    return Padding(
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
    );
  }

  Widget _buildVerifyingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildCodeBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_codeLength, (index) => _buildCodeBox(index)),
    );
  }

  Widget _buildCodeBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_isVerifying,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: filled ? KoraColors.purple : const Color(0xFF2E2E42),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KoraColors.purple, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: filled ? KoraColors.purple : const Color(0xFF2E2E42),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: KoraColors.darkCard,
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
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
        else if (_isResending)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: KoraColors.purple),
          )
        else
          GestureDetector(
            onTap: _resend,
            child: const Text(
              'Resend code',
              style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
