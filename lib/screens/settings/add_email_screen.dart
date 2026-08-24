import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';
import '../../services/auth_service.dart';
import 'add_email_verify_screen.dart';

/// "Add your email" screen — mirrors the reference design (WhatsApp-style)
/// but themed with Kora's purple-to-blue brand identity.
///
/// Lets the user set or change the email address tied to their account.
/// The "Next" button enables once a valid email is entered, then sends
/// a verification code to that address before applying the change.
class AddEmailScreen extends StatefulWidget {
  final String userId;
  final String? currentEmail;

  const AddEmailScreen({
    super.key,
    required this.userId,
    this.currentEmail,
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

    if (widget.currentEmail != null &&
        newEmail == widget.currentEmail!.trim().toLowerCase()) {
      setState(() => _errorMessage = 'This is already your current email.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.instance.sendVerificationCode(
        newEmail,
        type: 'changeEmail',
      );

      if (!mounted) return;

      if (result.success) {
        final confirmed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => AddEmailVerifyScreen(
              userId: widget.userId,
              newEmail: newEmail,
            ),
          ),
        );

        if (!mounted) return;
        setState(() => _isSending = false);

        if (confirmed == true) {
          Navigator.of(context).pop(newEmail);
        }
      } else {
        setState(() {
          _isSending = false;
          _errorMessage = result.error ?? 'Failed to send verification code.';
        });
      }
    } catch (_) {
      if (!mounted) return;
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
          style: TextStyle(
            color: textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
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
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
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
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
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
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
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
