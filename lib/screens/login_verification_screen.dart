import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'profile_setup_screen.dart';
import 'kora_home_screen.dart';
import '../services/crash_logger.dart';

/// Login verification screen for new devices.
///
/// Shown when a user logs in from a device the backend doesn't recognize.
/// Features:
/// - 6-digit code entry with auto-verify (no button press needed)
/// - "Recognize this device" toggle (saves device for future auto-login)
/// - Resend code with 60s countdown
/// - Clipboard auto-fill
/// - Kora's dark theme design language
class LoginVerificationScreen extends StatefulWidget {
  final String email;

  const LoginVerificationScreen({super.key, required this.email});

  @override
  State<LoginVerificationScreen> createState() => _LoginVerificationScreenState();
}

class _LoginVerificationScreenState extends State<LoginVerificationScreen>
    with WidgetsBindingObserver {
  static const int _codeLength = 6;
  static const int _resendCooldownSeconds = 60;

  final AuthService _auth = AuthService.instance;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _countdownTimer;
  Timer? _clipboardTimer;
  int _countdown = _resendCooldownSeconds;
  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _recognizeDevice = true;
  bool _verifyTriggered = false;
  String _initialClipboard = '';

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
    _snapshotClipboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkClipboard());
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
      _initialClipboard = text;
      _fillCode(match.group(1)!);
    } catch (_) {
      // Ignore clipboard access errors.
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
      final result = await _auth.verifyLogin(
        email: widget.email,
        code: _enteredCode,
        recognizeDevice: _recognizeDevice,
      );

      if (!mounted) return;

      if (result.success && result.user != null) {
        // Fetch fresh profile from backend
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
        await ChatThemeProvider.instance.load(); // Refresh owner/premium status for badge + gating
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kora_last_email', widget.email);
        if (!mounted) return;

        final user = KoraUserSession.fromMap(result.user!);
        if (user.profileCompleted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ProfileSetupScreen(
                email: result.user!['email'] as String,
                userData: result.user!,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = result.error ?? 'Verification failed';
        });
        _clearInputs();
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'LoginVerificationScreen._verify');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
        _clearInputs();
      }
    }
  }

  // ── Resend ──────────────────────────────────────────────────────

  void _startCountdown() {
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

    try {
      final result = await _auth.sendVerificationCode(widget.email, type: 'login');
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
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String get _maskedEmail => _auth.maskEmail(widget.email);

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

              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'New Device Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'For your security, we sent a verification code\nto your email to confirm it\'s you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Code sent to $_maskedEmail',
                      style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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

              if (_isVerifying)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              _buildRecognizeToggle(),
              const SizedBox(height: 24),

              _buildResendSection(),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Codes expire in 10 minutes.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New devices become trusted after 1 month of use.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11),
                      ),
                    ],
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
    );
  }

  Widget _buildRecognizeToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoraColors.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Color(0xFF6B6B80), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Recognize this device next time',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _recognizeDevice,
            onChanged: (value) => setState(() => _recognizeDevice = value),
            activeThumbColor: KoraColors.purple,
          ),
        ],
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
