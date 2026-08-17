import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../widgets/kora_button.dart';
import '../services/auth_service.dart';
import 'kora_home_screen.dart';

/// Profile Setup — shown after successful registration verification.
/// Generates a Kora ID and lets the user confirm their profile before
/// entering the main Kora experience.
class ProfileSetupScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? userData;

  const ProfileSetupScreen({
    super.key,
    required this.email,
    this.userData,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthService _auth = AuthService.instance;
  late final String _koraId;
  bool _isEntering = false;

  @override
  void initState() {
    super.initState();
    _koraId = _auth.generateKoraId();
  }

  void _enterKora() {
    setState(() => _isEntering = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.userData?['fullName'] as String? ?? 'User';
    final username = widget.userData?['username'] as String? ?? '';
    final initials = _getInitials(fullName);

    return Scaffold(
      backgroundColor: KoraColors.trueBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Success checkmark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KoraColors.purple.withValues(alpha: 0.15),
                  border: Border.all(color: KoraColors.purple, width: 2),
                ),
                child: const Icon(Icons.check, color: KoraColors.purple, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Account Created!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to Kora, $fullName',
                style: const TextStyle(color: Color(0xFFA0A0B8), fontSize: 15),
              ),
              const SizedBox(height: 36),

              // Profile card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: KoraColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF2E2E42), width: 1),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: KoraColors.brandGradient,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 14),
                      ),
                    const SizedBox(height: 16),

                    // Kora ID
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: KoraColors.trueBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KoraColors.purple.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Kora ID:  ',
                            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 14),
                          ),
                          Text(
                            _koraId,
                            style: const TextStyle(
                              color: KoraColors.purple,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              KoraButton(
                label: 'Enter Kora',
                onPressed: _enterKora,
                isLoading: _isEntering,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}
