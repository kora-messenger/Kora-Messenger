import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import 'email_change_verify_screen.dart';

/// "Add your email" screen — user enters a new email address.
///
/// On "Next":
/// 1. A loading popup appears.
/// 2. The backend sends a verification code to the OLD email.
/// 3. The user is taken to [EmailChangeVerifyScreen] (step 1 of 2).
///
/// The full flow is: old email code → new email code → email updated.
class AddEmailScreen extends StatefulWidget {
  final String userId;
  final String currentEmail;

  const AddEmailScreen({
    super.key,
    required this.userId,
    required this.currentEmail,
  });

  @override
  State<AddEmailScreen> createState() => _AddEmailScreenState();
}

class _AddEmailScreenState extends State<AddEmailScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  String? _errorMessage;

  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\.\-]+$');

  bool get _isValid => _emailRegex.hasMatch(_controller.text.trim());

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (!_isValid || _isSending) return;

    final newEmail = _controller.text.trim().toLowerCase();

    if (newEmail == widget.currentEmail.trim().toLowerCase()) {
      setState(() => _errorMessage = 'This is already your current email.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    // Show loading popup
    if (mounted) {
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
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(color: KoraColors.purple, strokeWidth: 2.8),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Sending code...',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final result = await AuthService.instance.initiateEmailChange(
        userId: widget.userId,
        oldEmail: widget.currentEmail,
        newEmail: newEmail,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // pop loading dialog

      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailChangeVerifyScreen(
              userId: widget.userId,
              oldEmail: widget.currentEmail,
              newEmail: newEmail,
            ),
          ),
        ).then((confirmed) {
          if (confirmed == true && mounted) {
            Navigator.of(context).pop(newEmail);
          }
        });
      } else {
        setState(() {
          _isSending = false;
          _errorMessage = result.error ?? 'Failed to send verification code.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // pop loading dialog
      setState(() {
        _isSending = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final hint = KoraColors.hintFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add your email',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: textSecondary, fontSize: 14.5, height: 1.5),
                  children: [
                    const TextSpan(
                      text: 'Email helps us verify your account or reach you in '
                          'case of security or support issues. Your email address '
                          "won't be visible to others. ",
                    ),
                    TextSpan(
                      text: 'Learn more',
                      style: TextStyle(color: KoraColors.purple, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onNext(),
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: TextStyle(color: hint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: KoraColors.purple, width: 1.6),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isValid ? KoraColors.brandGradient : null,
                      color: _isValid ? null : KoraColors.surfaceFor(brightness),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: ElevatedButton(
                      onPressed: _isValid && !_isSending ? _onNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: _isValid ? Colors.white : hint,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
