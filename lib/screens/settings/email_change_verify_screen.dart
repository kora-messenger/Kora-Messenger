import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';

/// Two-step email change verification screen.
///
/// Step 1: Enter code sent to the OLD email → verify → backend sends
///         code to the NEW email.
/// Step 2: Enter code sent to the NEW email → verify → backend updates
///         the email and sends a security alert to the old email.
///
/// After step 2 succeeds, a success popup shows "Your email has been
/// securely updated" and the user is returned to the Email Address
/// screen with the new email.
class EmailChangeVerifyScreen extends StatefulWidget {
  final String userId;
  final String oldEmail;
  final String newEmail;

  const EmailChangeVerifyScreen({
    super.key,
    required this.userId,
    required this.oldEmail,
    required this.newEmail,
  });

  @override
  State<EmailChangeVerifyScreen> createState() => _EmailChangeVerifyScreenState();
}

class _EmailChangeVerifyScreenState extends State<EmailChangeVerifyScreen> {
  static const int _codeLength = 6;
  int _step = 1; // 1 = old email, 2 = new email

  late final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCountdown = 60;

  String get _enteredCode => _controllers.map((c) => c.text).join();
  String get _currentEmail => _step == 1 ? widget.oldEmail : widget.newEmail;
  String get _currentType => _step == 1 ? 'emailChangeOld' : 'changeEmail';

  @override
  void initState() {
    super.initState();
    _setupKeyHandlers();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _setupKeyHandlers() {
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

  void _startResendCountdown() {
    Future<void> tick() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (_resendCountdown <= 0) return;
      setState(() => _resendCountdown--);
      if (_resendCountdown > 0) tick();
    }
    tick();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
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
      if (nextIndex < _codeLength) _focusNodes[nextIndex].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  void _fillCode(String digits) {
    final clean = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < _codeLength || !mounted) return;
    for (int i = 0; i < _codeLength; i++) {
      _controllers[i].text = clean[i];
    }
    _focusNodes[_codeLength - 1].unfocus();
    setState(() => _errorMessage = null);
  }

  void _onBackspaceOnEmptyBox(int index) {
    if (index == 0) return;
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    setState(() {});
  }

  bool get _isCodeComplete => _enteredCode.length == _codeLength;

  void _clearInputs() {
    for (final c in _controllers) c.clear();
    if (mounted) setState(() {});
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _isVerifying) return;
    setState(() => _errorMessage = null);

    final result = await AuthService.instance.resendEmailChangeCode(
      email: _currentEmail,
      type: _currentType,
    );

    if (!mounted) return;
    if (result.success) {
      setState(() => _resendCountdown = 60);
      _startResendCountdown();
    } else {
      setState(() => _errorMessage = result.error ?? 'Failed to resend code');
    }
  }

  /// Shows a "Verifying..." popup dialog.
  void _showVerifyingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: KoraColors.cardFor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.8),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verifying...',
                  style: TextStyle(
                    color: KoraColors.textPrimaryFor(Theme.of(context).brightness),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a success popup with a checkmark.
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: KoraColors.cardFor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your email has been\nsecurely updated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KoraColors.textPrimaryFor(Theme.of(context).brightness),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A security notification was sent to\nyour previous email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KoraColors.textSecondaryFor(Theme.of(context).brightness),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KoraColors.brandGradient,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // pop success dialog
                        Navigator.of(context).pop(true); // pop verify screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (!_isCodeComplete || _isVerifying) return;

    TextInput.finishAutofillContext();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    _showVerifyingDialog();

    try {
      if (_step == 1) {
        // Verify old email code → backend sends code to new email
        final result = await AuthService.instance.verifyOldEmailForChange(
          oldEmail: widget.oldEmail,
          newEmail: widget.newEmail,
          code: _enteredCode,
        );

        if (!mounted) return;
        Navigator.of(context).pop(); // pop verifying dialog

        if (result.success) {
          // Move to step 2
          setState(() {
            _step = 2;
            _isVerifying = false;
            _resendCountdown = 60;
            _errorMessage = null;
          });
          _clearInputs();
          _startResendCountdown();
        } else {
          setState(() {
            _isVerifying = false;
            _errorMessage = result.error ?? 'Invalid verification code';
          });
          _clearInputs();
        }
      } else {
        // Step 2: Verify new email code → update email
        final result = await AuthService.instance.verifyAndUpdateEmail(
          userId: widget.userId,
          newEmail: widget.newEmail,
          oldEmail: widget.oldEmail,
          code: _enteredCode,
        );

        if (!mounted) return;
        Navigator.of(context).pop(); // pop verifying dialog

        if (result.success) {
          // Update session
          if (result.user != null) {
            await SessionManager.instance.updateSession(result.user!);
          } else {
            await SessionManager.instance.updateSession({'email': widget.newEmail});
          }
          if (!mounted) return;
          _showSuccessDialog();
        } else {
          setState(() {
            _isVerifying = false;
            _errorMessage = result.error ?? 'Invalid verification code';
          });
          _clearInputs();
        }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // pop verifying dialog
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
      _clearInputs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final border = KoraColors.borderFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(false),
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
                _step == 1 ? 'Verify your email address' : 'Verify your new email',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: textSecondary, fontSize: 15, height: 1.5),
                  children: [
                    TextSpan(text: _step == 1
                        ? 'Enter the 6-digit code we sent to your current email '
                        : 'Enter the 6-digit code we sent to '),
                    if (_step == 2)
                      TextSpan(
                        text: widget.newEmail,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                      ),
                    if (_step == 1)
                      TextSpan(
                        text: widget.oldEmail,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              if (_step == 2) ...[
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 32),

              // 6-digit code boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_codeLength, (i) {
                  final hasError = _errorMessage != null;
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: i == 0 ? _codeLength : 1,
                      autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                      enabled: !_isVerifying,
                      style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: card,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: hasError ? Colors.redAccent : border, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: hasError ? Colors.redAccent : border, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: KoraColors.purple, width: 1.8),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13.5)),
              ],

              const SizedBox(height: 28),

              // Verify email button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isCodeComplete && !_isVerifying ? KoraColors.brandGradient : null,
                    color: _isCodeComplete && !_isVerifying ? null : KoraColors.surfaceFor(brightness),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ElevatedButton(
                    onPressed: _isCodeComplete && !_isVerifying ? _verify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: Text(
                      'Verify email',
                      style: TextStyle(
                        color: _isCodeComplete && !_isVerifying ? Colors.white : textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Center(
                child: TextButton(
                  onPressed: _resendCountdown > 0 || _isVerifying ? null : _resendCode,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend email',
                    style: TextStyle(
                      color: _resendCountdown > 0 ? textSecondary : KoraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
