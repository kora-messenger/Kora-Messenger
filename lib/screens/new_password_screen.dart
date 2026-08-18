import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String verificationCode;

  const NewPasswordScreen({
    super.key,
    required this.email,
    required this.verificationCode,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final AuthService _auth = AuthService.instance;
  bool _isLoading = false;
  bool _passwordUpdated = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a new password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _auth.verifyAndResetPassword(
      email: widget.email,
      code: widget.verificationCode,
      newPassword: _passwordController.text,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isLoading = false;
        _passwordUpdated = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LogInScreen()),
        (route) => false,
      );
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error ?? 'Failed to reset password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_passwordUpdated) {
      return _buildSuccessScreen();
    }

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Create New Password',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a strong password for your account.',
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1517),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                KoraInput(
                  label: 'New password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validatePassword,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                  ),
                ),
                const SizedBox(height: 16),

                KoraInput(
                  label: 'Confirm new password',
                  controller: _confirmController,
                  obscureText: true,
                  validator: _validateConfirm,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                  ),
                ),
                const SizedBox(height: 28),

                KoraButton(
                  label: 'Update Password',
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KoraColors.purple.withValues(alpha: 0.15),
                    border: Border.all(color: KoraColors.purple, width: 2),
                  ),
                  child: const Icon(Icons.check, color: KoraColors.purple, size: 44),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Password Updated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your password has been changed successfully. Redirecting to login...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: KoraColors.purple,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
