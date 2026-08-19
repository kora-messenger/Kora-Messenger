import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/kora_colors.dart';
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
/// - Kora's dark theme design language
class LoginVerificationScreen extends StatefulWidget {
  final String email;

  const LoginVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<LoginVerificationScreen> createState() => _LoginVerificationScreenState();
}

class _LoginVerificationScreenState extends State<LoginVerificationScreen>
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
  bool _recognizeDevice = true;
  String? _initialClipboard;
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
    _snapshotClipboard();
    // Auto-focus the first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
    // Poll clipboard for codes copied from notifications
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _checkClipboard();
    });
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    if (_enteredCode.length >= 6 || _isVerifying) return;
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text == _initialClipboard) return;
      final match = RegExp(r'(\d{6})').firstMatch(text);
      if (match != null) {
        _fillCode(match.group(1)!);
      }
    } catch (_) {}
  }

  void _fillCode(String code) {
    final sixDigits = code.replaceAll(RegExp(r'[^\d]'), '');
    if (sixDigits.length < 6) return;
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = sixDigits[i];
    }
    _focusNodes[5].unfocus();
    setState(() {});
    _onCodeChanged();
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

  String get _maskedEmail => _auth.maskEmail(widget.email);
  String get _enteredCode => _controllers.map((c) => c.text).join();

  /// Auto-verify when all 6 digits are entered.
  void _onCodeChanged() {
    if (_enteredCode.length == 6 && !_isVerifying) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_isVerifying) return;

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
      // Save session
      await SessionManager.instance.saveSession(result.user!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kora_last_email', email);
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

  Future<void> _resend() async {
    if (_countdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

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

    setState(() => _isResending = false);
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
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

              // Shield icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [KoraColors.purple, KoraColors.blue],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
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

              // Code boxes
              _buildCodeBoxes(),
              const SizedBox(height: 16),

              // Error message
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

              // Loading indicator (auto-verify in progress)
              if (_isVerifying)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: KoraColors.purple,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Recognize this device toggle
              _buildRecognizeToggle(),
              const SizedBox(height: 24),

              // Resend section
              _buildResendSection(),
              const Spacer(),

              // Info about device trust
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Codes expire in 10 minutes.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New devices become trusted after 1 month of use.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 11,
                        ),
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
                      : const Color(0xFF2A2A3E),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KoraColors.purple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFF14141F),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              if (value.length == 1 && index < 5) {
                _focusNodes[index + 1].requestFocus();
              }
              setState(() {});
              _onCodeChanged();
            },
            onTap: () {
              if (_controllers[index].text.isNotEmpty) {
                _controllers[index].clear();
                setState(() {});
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildRecognizeToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _recognizeDevice = !_recognizeDevice);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF14141F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _recognizeDevice
                ? KoraColors.purple.withValues(alpha: 0.5)
                : const Color(0xFF2A2A3E),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _recognizeDevice ? KoraColors.purple : const Color(0xFF6B6B80),
                  width: 2,
                ),
                color: _recognizeDevice ? KoraColors.purple : Colors.transparent,
              ),
              child: _recognizeDevice
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognize this device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _recognizeDevice
                        ? 'You won\'t need a code next time you log in here.'
                        : 'You\'ll need a verification code each time you log in.',
                    style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    if (_countdown > 0) {
      return Center(
        child: Text(
          'Resend code in ${_countdown}s',
          style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
        ),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _resend,
        child: _isResending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: KoraColors.purple,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Resend code',
                style: TextStyle(
                  color: KoraColors.purple,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
