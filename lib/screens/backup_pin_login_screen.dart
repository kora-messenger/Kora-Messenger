import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/kora_colors.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/crash_logger.dart';
import 'kora_home_screen.dart';
import 'profile_setup_screen.dart';

/// Login using Backup PIN — alternative to email + password.
///
/// The user's email is pre-filled from the last session (if any).
/// User enters their 6-digit backup PIN. When all 6 digits are entered,
/// the login button automatically starts loading. On success, shows
/// "Login successful" and navigates to home screen.
class BackupPinLoginScreen extends StatefulWidget {
  const BackupPinLoginScreen({super.key});

  @override
  State<BackupPinLoginScreen> createState() => _BackupPinLoginScreenState();
}

class _BackupPinLoginScreenState extends State<BackupPinLoginScreen> {
  static const int _pinLength = 6;

  final AuthService _auth = AuthService.instance;
  late final List<TextEditingController> _controllers =
      List.generate(_pinLength, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes =
      List.generate(_pinLength, (_) => FocusNode());

  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _autoLoginTriggered = false;
  String? _errorMessage;

  String get _enteredPin => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
    _loadLastEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _setupFocusNodeKeyHandlers() {
    for (int i = 0; i < _pinLength; i++) {
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

  Future<void> _loadLastEmail() async {
    // Try to get the last used email from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('kora_last_email');
    if (mounted && lastEmail != null && lastEmail.isNotEmpty) {
      setState(() {
        _emailController.text = lastEmail;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _emailController.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Paste
      final digits = value.replaceAll(RegExp(r'[^\d]'), '');
      for (int i = 0; i < digits.length && (index + i) < _pinLength; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = index + digits.length;
      if (nextIndex < _pinLength) {
        _focusNodes[nextIndex].requestFocus();
      } else {
        _focusNodes[_pinLength - 1].unfocus();
      }
      setState(() => _errorMessage = null);
      _maybeAutoLogin();
      return;
    }

    if (value.isNotEmpty && index < _pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
    _maybeAutoLogin();
  }

  void _maybeAutoLogin() {
    if (_enteredPin.length == _pinLength && !_autoLoginTriggered && _emailController.text.trim().isNotEmpty) {
      _autoLoginTriggered = true;
      _login();
    }
  }

  void _onBackspaceOnEmptyBox(int index) {
    if (index == 0) return;
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    setState(() {
      _autoLoginTriggered = false;
    });
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) setState(() => _autoLoginTriggered = false);
    _focusNodes[0].requestFocus();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final pin = _enteredPin;

    if (email.isEmpty || pin.length < _pinLength) {
      setState(() => _errorMessage = 'Enter your email and 6-digit PIN');
      return;
    }

    // Close any autofill context
    TextInput.finishAutofillContext();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.loginWithBackupPin(email: email, pin: pin);

      if (!mounted) return;

      if (result.success && result.user != null) {
        // Save session
        await SessionManager.instance.saveSession(result.user!);

        // Save last email for next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kora_last_email', email);

        if (!mounted) return;

        // Show "Login successful" message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to home or profile setup
        final user = result.user!;
        final profileCompleted = user['profileCompleted'] == true;

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          if (profileCompleted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => ProfileSetupScreen(
                  email: email,
                  userData: user,
                ),
              ),
              (route) => false,
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.error ?? 'Login failed. Please try again.';
          _autoLoginTriggered = false;
        });
        _clearInputs();
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'BackupPinLogin._login');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
          _autoLoginTriggered = false;
        });
        _clearInputs();
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
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Center(
                child: Text(
                  'Login using Backup PIN',
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
                  'Enter your email and 6-digit backup PIN to log in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 28),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.email_outlined, color: Color(0xFF6B6B80), size: 22),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF2E2E42), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: KoraColors.purple, width: 2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF2E2E42), width: 1),
                  ),
                  filled: true,
                  fillColor: KoraColors.darkCard,
                ),
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 24),

              // PIN boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_pinLength, (index) => _buildPinBox(index)),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13))),
                    ],
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: SizedBox(
                      width: 26, height: 26,
                      child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5),
                    ),
                  ),
                ),

              const Spacer(),

              // Login button (auto-triggers but also available manually)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KoraColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading || _enteredPin.length < _pinLength
                        ? null
                        : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? KoraColors.purple : const Color(0xFF2E2E42), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KoraColors.purple, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? KoraColors.purple : const Color(0xFF2E2E42), width: 2),
            ),
            filled: true,
            fillColor: KoraColors.darkCard,
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
    );
  }
}
