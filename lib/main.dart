import 'package:flutter/material.dart';

void main() {
  runApp(const KoraMessengerApp());
}

/// Kora's own visual identity — a purple-to-blue gradient
/// inspired by the app icon, paired with a deep navy dark surface.
class KoraColors {
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF3B82F6);
  static const Color deepNavy = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF13131F);
  static const Color lightBackground = Color(0xFFFAFAFC);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, blue],
  );
}

class KoraMessengerApp extends StatelessWidget {
  const KoraMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kora Messenger',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const WelcomeScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: KoraColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KoraColors.purple,
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: KoraColors.deepNavy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KoraColors.purple,
        brightness: Brightness.dark,
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final Color headlineColor = isDark ? Colors.white : const Color(0xFF14141F);
    final Color subtitleColor = isDark ? const Color(0xFFA0A0B8) : const Color(0xFF6B6B80);
    final Color footerColor = isDark ? const Color(0xFF6B6B80) : const Color(0xFFA0A0B0);
    final Color surfaceColor = isDark ? KoraColors.darkSurface : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: screenHeight * 0.06),

              // Branding section
              Column(
                children: [
                  // App icon (Kora's own K + chat-bubble mark)
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: KoraColors.purple.withOpacity(isDark ? 0.35 : 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon/kora_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Headline
                  Text(
                    'Welcome to Kora',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: headlineColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Container(
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
                    child: Text(
                      'Real conversations, reimagined. Connect with the '
                      'people who matter — instantly, and securely.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),

              // Buttons section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    // Primary — Create Account / Sign Up
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KoraColors.brandGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: KoraColors.purple.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // Navigate to Create Account screen (next stage)
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
                    const SizedBox(height: 14),

                    // Secondary — Log In
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          // Navigate to Log In screen (next stage)
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: headlineColor,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E2E42) : const Color(0xFFE0E0EA),
                            width: 1.5,
                          ),
                          backgroundColor: surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer — legal text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: footerColor, height: 1.5),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to Kora\'s\n'),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: isDark ? KoraColors.blue.withOpacity(0.9) : KoraColors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: isDark ? KoraColors.blue.withOpacity(0.9) : KoraColors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
