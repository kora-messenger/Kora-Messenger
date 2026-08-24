import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_manager.dart';

/// Confirms the new email address entered on [AddEmailScreen].
///
/// A 6-digit code was already sent to [newEmail]. Per Kora's standing
/// rule, verification auto-completes the moment the final digit is
/// entered — there is no manual submit button.
class AddEmailVerifyScreen extends StatefulWidget {
  final String userId;
  final String newEmail;

  const AddEmailVerifyScreen({
    super.key,
    required this.userId,
    required this.newEmail,
  });

  @override
  State<AddEmailVerifyScreen> createState() => _AddEmailVerifyScreenState();
}

class _AddEmailVerifyScreenState extends State<AddEmailVerifyScreen> {
  static const int _codeLength = 6;

  late final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCountdown = 60;

  String get _enteredCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupFocusNodeKeyHandlers();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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

  void _onBackspaceOnEmptyBox(int index) {
    if (index == 0) return;
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    setState(() {});
  }

  /// Auto-verifies the instant the final digit is entered — no submit
  /// button, per Kora's verification screen standard.
  void _maybeAutoVerify() {
    if (_enteredCode.length == _codeLength && !_isVerifying) {
      _verify();
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;
    setState(() => _errorMessage = null);

    final result = await AuthService.instance.sendVerificationCode(
      widget.newEmail,
      type: 'changeEmail',
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => _resendCountdown = 60);
      _startResendCountdown();
    } else {
      setState(() => _errorMessage = result.error ?? 'Failed to resend code');
    }
  }

  Future<void> _verify() async {
    if (_enteredCode.length < _codeLength || _isVerifying) return;

    TextInput.finishAutofillContext();

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.instance.verifyAndUpdateEmail(
        userId: widget.userId,
        newEmail: widget.newEmail,
        code: _enteredCode,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.user != null) {
          await SessionManager.instance.updateSession(result.user!);
        } else {
          await SessionManager.instance.updateSession({'email': widget.newEmail});
        }
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = result.error ?? 'Invalid verification code';
        });
        _clearInputs();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
      _clearInputs();
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
                'Confirm your email',
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
                    const TextSpan(text: 'Enter the 6-digit code we sent to '),
                    TextSpan(
                      text: widget.newEmail,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
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
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: card,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: hasError ? Colors.redAccent : border,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: hasError ? Colors.redAccent : border,
                            width: 1,
                          ),
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
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13.5),
                ),
              ],

              const SizedBox(height: 24),

              if (_isVerifying)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.5),
                    ),
                  ),
                ),

              const Spacer(),

              Center(
                child: TextButton(
                  onPressed: _resendCountdown > 0 ? null : _resendCode,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend code',
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
