import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';

/// Full-screen welcome popup shown to new users after they complete
/// registration and enter Kora for the first time.
///
/// Displays a Kora-branded welcome message and the 7-day Premium
/// trial announcement. The only action is "Start Exploring Kora" —
/// no skip, no "Maybe Later", no dismiss option.
class NewUserWelcomePopup extends StatefulWidget {
  final String userFullName;

  const NewUserWelcomePopup({
    super.key,
    required this.userFullName,
  });

  @override
  State<NewUserWelcomePopup> createState() => _NewUserWelcomePopupState();
}

class _NewUserWelcomePopupState extends State<NewUserWelcomePopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _startExploring() {
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A0A14), Color(0xFF13131F)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: KoraColors.purple.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KoraColors.purple.withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kora logo badge
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [KoraColors.purple, KoraColors.blue],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: KoraColors.purple.withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'K',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Welcome title
                      const Text(
                        'Welcome to Kora! 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We're happy to have you here. Your Kora journey starts now.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: KoraColors.textSecondaryFor(Brightness.dark),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Premium gift card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              KoraColors.purple.withValues(alpha: 0.12),
                              KoraColors.blue.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: KoraColors.purple.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '🎁',
                              style: TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '7 Days of Kora Premium — FREE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "You've received a free 7-day Premium experience. Explore Kora and enjoy the Premium features already available on your account.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: KoraColors.textSecondaryFor(Brightness.dark),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Start Exploring Kora button — the only action
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: GestureDetector(
                          onTap: _startExploring,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [KoraColors.purple, KoraColors.blue],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: KoraColors.purple.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Start Exploring Kora',
                                style: TextStyle(
                                  color: Colors.white,
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
            ),
          ),
        ),
      ),
    );
  }
}
