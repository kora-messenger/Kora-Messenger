import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import '../../services/crash_logger.dart';

/// Verification screen for enabling/disabling 2FA.
///
/// The user's email is auto-filled and read-only. They tap "Send code"
/// to receive a verification code, enter the 6 digits, and tap "Verify".
/// On success, pops back with `true` so the 2FA toggle updates.
class TwoFactorVerifyScreen extends StatefulWidget {
  final String email;
  final bool enabling;

  const TwoFactorVerifyScreen({
    super.key,
    required this.email,
    required this.enabling,
  });

  @override
  State<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends State<TwoFactorVerifyScreen> {
  static const int _codeLength = 6;

  final AuthService _auth = AuthService.instance;
  late final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCountdown = 0;

  String get _enteredCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
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

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.sendVerificationCode(
        widget.email,
        type: 'login', // reuse login-type verification for 2FA
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _codeSent = true;
          _isSending = false;
          _resendCountdown = 60;
        });
        _startResendCountdown();
        // Auto-focus first digit box
        _focusNodes[0].requestFocus();
      } else {
        setState(() {
          _isSending = false;
          _errorMessage = result.error ?? 'Failed to send code';
        });
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'TwoFactorVerify._sendCode');
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
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

  Future<void> _verify() async {
    if (_enteredCode.length < _codeLength || _isVerifying) return;

    // Close autofill context before navigating
    TextInput.finishAutofillContext();

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await _auth.verifyCode(
        email: widget.email,
        code: _enteredCode,
        type: 'login',
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = result.error ?? 'Invalid verification code';
        });
        _clearInputs();
      }
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'TwoFactorVerify._verify');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
        _clearInputs();
      }
    }
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) setState(() {});
    _focusNodes[0].requestFocus();
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
          onPressed: () => Navigator.of(context).pop(false),
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
                widget.enabling ? 'Enable 2FA' : 'Disable 2FA',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.enabling
                    ? 'Confirm it\'s you by entering the verification code sent to your email.'
                    : 'Confirm it\'s you before disabling Two-Factor Authentication.',
                style: TextStyle(color: textSecondary, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 28),

              // Email field (auto-filled, read-only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(widget.email, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Send code / Code input section
              if (!_codeSent) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KoraColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Send code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ] else ...[
                // Code input boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_codeLength, (index) => _buildCodeBox(index, textPrimary, card, border)),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent.shade400, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.redAccent.shade400, fontSize: 13))),
                      ],
                    ),
                  ),
                if (_isVerifying)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5))),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KoraColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isVerifying || _enteredCode.length < _codeLength ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: KoraColors.purple.withValues(alpha: 0.3),
                      ),
                      child: Text('Verify', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Didn't get the code? ", style: TextStyle(color: textSecondary, fontSize: 14)),
                    if (_resendCountdown > 0)
                      Text('Resend in ${_resendCountdown}s', style: TextStyle(color: textMuted, fontSize: 14))
                    else
                      GestureDetector(
                        onTap: _sendCode,
                        child: const Text('Resend code', style: TextStyle(color: KoraColors.purple, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Text('Codes expire in 10 minutes.', style: TextStyle(color: textMuted, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index, Color textPrimary, Color card, Color border) {
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
          autofocus: index == 0,
          style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? KoraColors.purple : border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KoraColors.purple, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: filled ? KoraColors.purple : border, width: 2),
            ),
            filled: true,
            fillColor: card,
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
    );
  }
}
