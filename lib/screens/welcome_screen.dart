import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/kora_api.dart';

/// Paints a glowing star with a gradient trail that orbits around a center
/// point — reused on the Welcome screen to echo the splash screen's motif.
class _OrbitingStarPainter extends CustomPainter {
  final double progress;

  _OrbitingStarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = size.width * 0.46;

    final angle = progress * 2 * math.pi - math.pi / 2;

    // Faint orbit ring — shows the circular path
    final ringPaint = Paint()
      ..color = KoraColors.purple.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, orbitRadius, ringPaint);

    // Outer glow
    final glowPaint = Paint()
      ..color = KoraColors.purple.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + orbitRadius * math.cos(angle),
             center.dy + orbitRadius * math.sin(angle)),
      9, glowPaint,
    );

    // Star body
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + orbitRadius * math.cos(angle),
             center.dy + orbitRadius * math.sin(angle)),
      3.5, starPaint,
    );

    // Core
    final corePaint = Paint()
      ..color = KoraColors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + orbitRadius * math.cos(angle),
             center.dy + orbitRadius * math.sin(angle)),
      1.8, corePaint,
    );
  }

  @override
  bool shouldRepaint(_OrbitingStarPainter old) => old.progress != progress;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    // One full round (orbit) then settle at the top — no cycling.
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // The Welcome screen keeps a fixed near-black identity regardless of
    // system theme — this is Kora's brand splash, not a themed page.
    const Color bg = KoraColors.trueBlack;
    const Color headlineWhite = Colors.white;
    const Color subtitleColor = Color(0xFFA0A0B8);
    const Color footerColor = Color(0xFF7A7A90);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.045),

              // Logo lockup with orbiting star animation
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Orbiting star layer
                    AnimatedBuilder(
                      animation: _starController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(160, 160),
                          painter: _OrbitingStarPainter(_starController.value),
                        );
                      },
                    ),
                    // Kora logo
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: KoraColors.purple.withValues(alpha: 0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/images/kora_logo_lockup.webp',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Wordmark headline — "Kora" purple + "Messenger" white
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: 'Kora ', style: TextStyle(color: KoraColors.purple)),
                    TextSpan(text: 'Messenger', style: TextStyle(color: headlineWhite)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Connect with anyone, anywhere, anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                ),
              ),

              // World map — decorative connectivity visual, fills the
              // remaining space between the header and the buttons.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Opacity(
                      opacity: 0.9,
                      child: Image.asset(
                        'assets/images/world_map_glow.webp',
                        width: screenWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Buttons — Log In (primary pill) then Create Account (secondary pill)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    // Primary — Log In (solid purple pill)
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KoraColors.purple,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: KoraColors.purple.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              Navigator.of(context).push(
                                _buildSlideRoute(const LogInScreen()),
                              );
                            },
                            child: const Center(
                              child: Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Secondary — Create Account (dark pill)
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KoraColors.darkPill,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              Navigator.of(context).push(
                                _buildSlideRoute(const SignUpScreen()),
                              );
                            },
                            child: const Center(
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer — legal text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                child: Column(
                  children: [
                    Text(
                      'By continuing, you agree to our',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: footerColor, height: 1.5),
                    ),
                    SizedBox(height: 2),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(KoraApi.privacyPolicyUrl);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: Text(
                        'Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KoraColors.purple,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          decoration: TextDecoration.underline,
                          decorationColor: KoraColors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smooth slide-up + fade transition for navigating between auth screens.
PageRouteBuilder _buildSlideRoute(Widget screen) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnim = Tween<Offset>(
        begin: const Offset(0.0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: offsetAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
  );
}
