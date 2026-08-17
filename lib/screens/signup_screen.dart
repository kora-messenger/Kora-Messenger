import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../services/auth_service.dart';
import '../widgets/kora_input.dart';
import '../widgets/kora_button.dart';
import 'verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter a username';
    if (value.trim().length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers and underscores allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            type: VerificationType.registration,
            email: _emailController.text.trim(),
            userData: {
              'fullName': _nameController.text.trim(),
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 8),
              const Text(
                'Create your account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join Kora and start connecting today.',
                style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
              ),
              const SizedBox(height: 32),

              // Profile photo placeholder
              _buildPhotoPicker(),
              const SizedBox(height: 24),

              KoraInput(
                label: 'Full name',
                controller: _nameController,
                keyboardType: TextInputType.name,
                validator: _validateName,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.person_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              KoraInput(
                label: 'Username',
                controller: _usernameController,
                keyboardType: TextInputType.text,
                validator: _validateUsername,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.alternate_email, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              KoraInput(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.email_outlined, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 16),

              KoraInput(
                label: 'Password',
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
                label: 'Confirm password',
                controller: _confirmPasswordController,
                obscureText: true,
                validator: _validateConfirmPassword,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline, color: Color(0xFF6B6B80), size: 22),
                ),
              ),
              const SizedBox(height: 28),

              KoraButton(
                label: 'Create Account',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),

              // Already have an account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Color(0xFFA0A0B8), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: KoraColors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: KoraColors.trueBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: GestureDetector(
        onTap: () {
          // TODO: Integrate image_picker when ready
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo upload coming soon'),
              backgroundColor: KoraColors.darkCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KoraColors.darkCard,
            border: Border.all(color: const Color(0xFF2E2E42), width: 2),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, color: Color(0xFF6B6B80), size: 28),
              SizedBox(height: 4),
              Text(
                'Add Photo',
                style: TextStyle(color: Color(0xFF6B6B80), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
