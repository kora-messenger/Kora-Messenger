import 'package:flutter/material.dart';
import 'theme/kora_colors.dart';
import 'screens/welcome_screen.dart';
import 'screens/kora_home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/session_manager.dart';

void main() {
  runApp(const KoraMessengerApp());
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
      home: const SplashScreen(),
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

/// Checks for a saved session on startup and routes accordingly:
/// - No session → WelcomeScreen
/// - Session with profileCompleted → KoraHomeScreen
/// - Session without profileCompleted → ProfileSetupScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await SessionManager.instance.loadSession();

    if (!mounted) return;

    if (session == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      final profileCompleted = session['profileCompleted'] == true;
      if (profileCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              email: session['email']?.toString() ?? '',
              userData: session,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? KoraColors.deepNavy : KoraColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: KoraColors.brandGradient,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KoraColors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
