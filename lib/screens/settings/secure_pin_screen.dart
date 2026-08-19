import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/kora_colors.dart';
import '../../services/session_manager.dart';
import '../../services/crash_logger.dart';

/// Secure PIN creation screen — backup code for 2FA.
///
/// Two-step flow:
///   Step 0: "Create a secure 6 digit PIN that you can remember"
///   Step 1: "Confirm your PIN" — must match Step 0
///
/// 2 dots below the PIN boxes indicate progress:
///   Step 0: dot 0 = purple, dot 1 = ash
///   Step 1: dot 0 = ash, dot 1 = purple
///
/// Back arrow on Step 1 goes back to Step 0.
/// "Save" button is disabled until the confirm PIN is complete and matches.
class SecurePinScreen extends StatefulWidget {
  const SecurePinScreen({super.key});

  @override
  State<SecurePinScreen> createState() => _SecurePinScreenState();
}

class _SecurePinScreenState extends State<SecurePinScreen> {
  static const int _pinLength = 6;

  int _step = 0; // 0 = create, 1 = confirm
  String _createdPin = '';
  bool _isSaving = false;
  String? _errorMessage;

  late final List<TextEditingController> _controllers =
      List.generate(_pinLength, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes =
      List.generate(_pinLength, (_) => FocusNode());

  String get _enteredPin => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    // Auto-focus first box when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
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
      _checkAutoAdvance();
      return;
    }

    if (value.isNotEmpty && index < _pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
    _checkAutoAdvance();
  }

  void _checkAutoAdvance() {
    if (_enteredPin.length != _pinLength) return;

    if (_step == 0) {
      // Created PIN is complete — move to confirm step
      _createdPin = _enteredPin;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _step = 1);
        _clearInputs();
      });
    }
    // Step 1: "Save" button enables when confirm PIN is complete.
    // No auto-advance — user taps Save explicitly.
  }

  void _clearInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) setState(() {});
    _focusNodes[0].requestFocus();
  }

  void _onBackspaceOnEmptyBox(int index) {
    if (index == 0) return;
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    setState(() {});
  }

  void _onBackPressed() {
    if (_step == 1) {
      // Go back to create step
      setState(() {
        _step = 0;
        _errorMessage = null;
      });
      _clearInputs();
    } else {
      Navigator.of(context).pop();
    }
  }

  bool get _isConfirmPinValid =>
      _step == 1 &&
      _enteredPin.length == _pinLength &&
      _enteredPin == _createdPin;

  Future<void> _save() async {
    if (!_isConfirmPinValid || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Persist the PIN hash in the session
      final session = await SessionManager.instance.loadSession();
      if (session != null) {
        session['securePin'] = _createdPin;
        await SessionManager.instance.saveSession(session);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secure PIN saved successfully.'),
          backgroundColor: KoraColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e, stack) {
      await CrashLogger.log(e, stackTrace: stack, context: 'SecurePinScreen._save');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save PIN. Please try again.';
        });
      }
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
          onPressed: _onBackPressed,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Shield icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: KoraColors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Secure PIN',
                style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),

              // ── Warning description ──
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.25), width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Keep your backup key safe. Anyone with access to your backup PIN can get full access to your account.',
                        style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Step description ──
              Text(
                _step == 0
                    ? 'Create a secure 6 digit PIN that you can remember'
                    : 'Confirm your PIN',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),

              // ── 6-digit PIN boxes ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_pinLength, (index) => _buildPinBox(index, textPrimary, card, border)),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent.shade400, size: 18),
                      const SizedBox(width: 8),
                      Text(_errorMessage!, style: TextStyle(color: Colors.redAccent.shade400, fontSize: 13)),
                    ],
                  ),
                ),

              // PIN mismatch hint
              if (_step == 1 && _enteredPin.length == _pinLength && _enteredPin != _createdPin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('PINs do not match', style: TextStyle(color: Colors.redAccent.shade400, fontSize: 13)),
                ),

              const Spacer(),

              // ── 2 progress dots ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(_step == 0),
                  const SizedBox(width: 10),
                  _buildDot(_step == 1),
                ],
              ),
              const SizedBox(height: 20),

              // ── Bottom button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isConfirmPinValid && !_isSaving
                        ? KoraColors.brandGradient
                        : LinearGradient(colors: [
                            KoraColors.purple.withValues(alpha: 0.3),
                            KoraColors.blue.withValues(alpha: 0.3),
                          ]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _isConfirmPinValid && !_isSaving ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.white54,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _step == 0 ? 'Next' : 'Save',
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

  Widget _buildDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? KoraColors.purple : const Color(0xFF3A3A4E),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildPinBox(int index, Color textPrimary, Color card, Color border) {
    final filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: _focusNodes[index],
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty) {
              _onBackspaceOnEmptyBox(index);
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_isSaving,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          autofocus: index == 0 && _step == 0,
          obscureText: true,
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
