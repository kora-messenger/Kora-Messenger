import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/kora_colors.dart';
import 'screens/welcome_screen.dart';
import 'screens/kora_home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/crash_report_screen.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/data_saver_service.dart';
import 'services/crash_logger.dart';
import 'services/connectivity_service.dart';
import 'services/offline_voice_sync.dart';
import 'services/message_service.dart';
import 'theme/chat_theme_provider.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize crash logging before anything else.
    CrashLogger.init();
    ChatThemeProvider.instance.load();

    // Initialize local notifications (creates channels + sets icon).
    KoraNotificationService.instance.init();

    // Cap in-memory image cache to reduce memory + data usage.
    DataSaverService.tuneImageCache();

    // Initialize connectivity monitoring and offline voice sync.
    ConnectivityService.instance.init();
    await MessageService.instance.init();
    await OfflineVoiceSyncService.instance.init();

    runApp(const KoraMessengerApp());
  }, (error, stackTrace) {
    // 3. Zone errors — any uncaught async/sync error in the root zone.
    CrashLogger.log(error, stackTrace: stackTrace, context: 'Zone', isFatal: true);
  });
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
/// - Unread crash → CrashReportScreen (then proceed to normal routing)
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
    _boot();
  }

  Future<void> _boot() async {
    // 1. Check for unread fatal crash from the previous run.
    final hasCrash = await CrashLogger.hasUnreadCrash();

    if (!mounted) return;

    if (hasCrash) {
      final crashLog = await CrashLogger.getUnreadCrash();
      if (!mounted) return;

      if (crashLog != null) {
        // Show the crash report screen. After the user dismisses it,
        // continue with normal session routing.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CrashReportScreen(
              crashLog: crashLog,
              onDismiss: () => _routeAfterCrash(),
            ),
          ),
        );
        return;
      }
    }

    // 2. Normal routing — no crash detected.
    _routeToSession();
  }

  Future<void> _routeAfterCrash() async {
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

  Future<void> _routeToSession() async {
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: KoraColors.purple.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/kora_logo_lockup.png',
                  fit: BoxFit.cover,
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
