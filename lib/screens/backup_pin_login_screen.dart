import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/kora_colors.dart';
import '../theme/chat_theme_provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/chat_sync_service.dart';
import '../services/crash_logger.dart';
import 'kora_home_screen.dart';
import 'profile_setup_screen.dart';

/// Mode of operation for [BackupPinLoginScreen].
enum BackupPinMode {
  /// Standard login with Email + 6-digit Backup PIN.
  login,

  /// Setting up end-to-end encrypted backup PIN.
  setupEncryption,

  /// Verifying PIN to decrypt or restore backup.
  verifyEncryption,
}

/// Screen for Backup PIN operations:
/// 1. Login using Backup PIN
/// 2. Creating an end-to-end backup encryption PIN
/// 3. Verifying backup PIN for restore or settings change
class BackupPinLoginScreen extends StatefulWidget {
  final BackupPinMode mode;
  final String? initialEmail;
  final ValueChanged<String>? onPinConfirmed;

  const BackupPinLoginScreen({
    super.key,
    this.mode = BackupPinMode.login,
    this.initialEmail,
    this.onPinConfirmed,
  });

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
  String? _confirmPin;
  bool _isConfirming = false;

  String get _enteredPin => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    } else {
      _loadLastEmail();
    }
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
      // Handle paste
      final digits = value.replaceAll(RegExp(r'[^\d]'), '');
      for (int i = 0; i < digits.length && (index + i) < _pinLength; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, _pinLength - 1);
      _focusNodes[nextIndex].requestFocus();
    } else if (value.isNotEmpty) {
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    setState(() {
      _errorMessage = null;
    });

    if (_enteredPin.length == _pinLength && !_autoLoginTriggered) {
      _handleSubmit();
    }
  }

  void _onBackspaceOnEmptyBox(int index) {
    if (index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {
        _errorMessage = null;
      });
    }
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handleSubmit() async {
    if (_enteredPin.length < _pinLength) return;

    switch (widget.mode) {
      case BackupPinMode.login:
        await _login();
        break;
      case BackupPinMode.setupEncryption:
        await _handleSetupEncryption();
        break;
      case BackupPinMode.verifyEncryption:
        await _handleVerifyEncryption();
        break;
    }
  }

  Future<void> _handleSetupEncryption() async {
    final pin = _enteredPin;

    if (!_isConfirming) {
      // First pass — save PIN and ask to confirm
      setState(() {
        _confirmPin = pin;
        _isConfirming = true;
        _errorMessage = null;
      });
      _clearInputs();
      return;
    }

    // Confirmation pass
    if (pin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _isConfirming = false;
        _confirmPin = null;
      });
      _clearInputs();
      return;
    }

    // Save encryption PIN
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kora_backup_encrypt_pin', pin);
    await prefs.setBool('kora_backup_encrypt', true);

    if (widget.onPinConfirmed != null) {
      widget.onPinConfirmed!(pin);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup encryption PIN set successfully'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(pin);
    }
  }

  Future<void> _handleVerifyEncryption() async {
    final pin = _enteredPin;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('kora_backup_encrypt_pin');

    // Default pin for testing if none set yet
    final isCorrect = (savedPin != null && savedPin == pin) || (savedPin == null && pin.length == 6);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (isCorrect) {
      if (widget.onPinConfirmed != null) {
        widget.onPinConfirmed!(pin);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup PIN verified'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
      _clearInputs();
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pin = _enteredPin;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
      });
      return;
    }

    if (pin.length < _pinLength) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of your PIN.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.loginWithBackupPin(email: email, pin: pin);

      if (!mounted) return;

      if (result.success && result.user != null) {
        await SessionManager.instance.saveSession(result.user!);
        await ChatThemeProvider.instance.load();
        await ChatThemeProvider.instance.syncPremiumFromSession(result.user!);
        
        final session = await SessionManager.instance.loadSession();
        if (session != null && session['email'] != null) {
          ChatSyncService.instance.setUserEmail(session['email'] as String);
          ChatSyncService.instance.setSenderName(
            (session['fullName'] as String?) ?? '',
          );
          await ChatSyncService.instance.restoreFromCloud();
          ChatSyncService.instance.startPolling();
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kora_last_email', email);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful'),
            backgroundColor: KoraColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

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
    final titleText = widget.mode == BackupPinMode.login
        ? 'Login using Backup PIN'
        : widget.mode == BackupPinMode.setupEncryption
            ? (_isConfirming ? 'Confirm Encryption PIN' : 'Create Encryption PIN')
            : 'Enter Encryption PIN';

    final subTitleText = widget.mode == BackupPinMode.login
        ? 'Enter your email and 6-digit backup PIN to log in.'
        : widget.mode == BackupPinMode.setupEncryption
            ? (_isConfirming
                ? 'Re-enter your 6-digit PIN to confirm.'
                : 'Create a 6-digit PIN to secure your encrypted backup. If you lose this PIN, Kora cannot recover your backup.')
            : 'Enter your 6-digit PIN to verify your identity and decrypt your backup.';

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
                  child: Icon(
                    widget.mode == BackupPinMode.login
                        ? Icons.lock_outline
                        : Icons.security,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Center(
                child: Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  subTitleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 28),

              // Email field (only shown for login mode)
              if (widget.mode == BackupPinMode.login) ...[
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
              ],

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

              // Submit button
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
                        : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                    ),
                    child: Text(
                      widget.mode == BackupPinMode.login
                          ? 'Log In'
                          : (widget.mode == BackupPinMode.setupEncryption
                              ? (_isConfirming ? 'Confirm PIN' : 'Next')
                              : 'Verify PIN'),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
            borderSide: const BorderSide(color: Color(0xFF2E2E42), width: 1),
          ),
          filled: true,
          fillColor: KoraColors.darkCard,
        ),
        onChanged: (val) => _onDigitChanged(index, val),
      ),
    );
  }
}
