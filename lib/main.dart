import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'theme/kora_colors.dart';
import 'config/kora_api.dart';
import 'services/auth_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/suspension_screen.dart';
import 'screens/kora_home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/crash_report_screen.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/kora_firebase_service.dart';
import 'services/data_saver_service.dart';
import 'services/crash_logger.dart';
import 'services/connectivity_service.dart';
import 'services/status_service.dart';
import 'services/status_trigger_service.dart';
import 'services/chat_sync_service.dart';
import 'services/offline_voice_sync.dart';
import 'services/translation_service.dart';
import 'services/message_service.dart';
import 'theme/chat_theme_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize crash logging before anything else.
    CrashLogger.init();
    ChatThemeProvider.instance.load();

    // Initialize local notifications (creates channels + sets icon).
    KoraNotificationService.instance.init();

    // Initialize Firebase FCM (push notifications).
    // Silently skips if google-services.json isn't configured.
    KoraFirebaseService.instance.init();

    // Cap in-memory image cache to reduce memory + data usage.
    DataSaverService.tuneImageCache();

    // Initialize connectivity monitoring and offline voice sync.
    ConnectivityService.instance.init();
    await MessageService.instance.init();
    await OfflineVoiceSyncService.instance.init();

    // Initialize translation service.
    await TranslationService.instance.init();
    await StatusService.instance.init();
    await StatusTriggerService.instance.init();

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

/// ─── Shooting Star Painter ──────────────────────────────────────────────
/// Draws a shooting star with a gradient trail that orbits around the logo.
class ShootingStarPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 for one full orbit

  ShootingStarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = size.width * 0.42;

    // Current angle — full 2π rotation over progress
    final angle = progress * 2 * math.pi - math.pi / 2; // start at top
    final starX = center.dx + orbitRadius * math.cos(angle);
    final starY = center.dy + orbitRadius * math.sin(angle);
    final starPos = Offset(starX, starY);

    // Trail — 8 segments behind the star
    const trailSteps = 18;
    for (int i = trailSteps; i >= 1; i--) {
      final trailAngle = angle - (i * 0.08);
      final tx = center.dx + orbitRadius * math.cos(trailAngle);
      final ty = center.dy + orbitRadius * math.sin(trailAngle);
      final tPos = Offset(tx, ty);
      final alpha = (1.0 - i / trailSteps) * 0.5;
      final trailPaint = Paint()
        ..color = KoraColors.purple.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tPos, (1.0 - i / trailSteps) * 2.5, trailPaint);
    }

    // The star itself — bright glowing dot
    final glowPaint = Paint()
      ..color = KoraColors.purple.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(starPos, 10, glowPaint);

    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(starPos, 4, starPaint);

    // Inner star core — brand color
    final corePaint = Paint()
      ..color = KoraColors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(starPos, 2, corePaint);
  }

  @override
  bool shouldRepaint(ShootingStarPainter old) => old.progress != progress;
}

/// Checks for a saved session on startup and routes accordingly:
/// - Unread crash → CrashReportScreen (then proceed to normal routing)
/// - No session → WelcomeScreen
/// - Session with profileCompleted → KoraHomeScreen
/// - Session without profileCompleted → ProfileSetupScreen
///
/// The splash screen displays briefly (~1.2s) before routing — logo animation only.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Brief 1.2s animation — just enough for the logo + star orbit
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Start boot almost immediately — don't block on animation
    Timer(const Duration(milliseconds: 1200), _boot);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    // ── App Lock: check biometric after crash dialog too ──
    if (session != null) {
      final prefs = await SharedPreferences.getInstance();
      final appLockEnabled = prefs.getBool('app_lock_enabled') ??
          prefs.getBool('kora_privacy_app_lock') ?? false;

      if (appLockEnabled) {
        final localAuth = LocalAuthentication();
        bool authenticated = false;
        try {
          final canCheck = await localAuth.canCheckBiometrics;
          if (canCheck) {
            authenticated = await localAuth.authenticate(
              localizedReason: 'Please authenticate to unlock Kora',
              authMessages: const <AuthMessages>[
                AndroidAuthMessages(
                  signInTitle: 'Unlock Kora',
                ),
                IOSAuthMessages(
                  cancelButton: 'Cancel',
                ),
              ],
            );
          }
        } catch (_) {
          authenticated = true;
        }

        if (!mounted) return;
        if (!authenticated) {
          SystemNavigator.pop();
          return;
        }
      }
    }

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

    // ── App Lock: if enabled and user has a session, prompt biometric ──
    if (session != null) {
      final prefs = await SharedPreferences.getInstance();
      final appLockEnabled = prefs.getBool('app_lock_enabled') ??
          prefs.getBool('kora_privacy_app_lock') ?? false;

      if (appLockEnabled) {
        final localAuth = LocalAuthentication();
        bool authenticated = false;

        try {
          final canCheck = await localAuth.canCheckBiometrics;
          if (canCheck) {
            authenticated = await localAuth.authenticate(
              localizedReason: 'Please authenticate to unlock Kora',
              authMessages: const <AuthMessages>[
                AndroidAuthMessages(
                  signInTitle: 'Unlock Kora',
                ),
                IOSAuthMessages(
                  cancelButton: 'Cancel',
                ),
              ],
            );
          }
        } catch (_) {
          // If biometric fails, fall through to app
          authenticated = true;
        }

        if (!mounted) return;

        if (!authenticated) {
          // User cancelled biometric — exit the app
          SystemNavigator.pop();
          return;
        }
      }
    }

    if (session == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      final email = session['email']?.toString() ?? '';

      // Check if account is suspended before navigating to home
      try {
        final suspResp = await http.post(
          Uri.parse(KoraApi.autoDetectEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'checkSuspensionStatus', 'email': email}),
        );
        final suspData = jsonDecode(suspResp.body);
        if (suspData['suspended'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SuspensionScreen(
                email: email,
                suspensionReason: suspData['reason'] ?? 'Your account has been suspended for violating Kora Messenger Community Guidelines.',
                isPermanent: suspData['isPermanent'] ?? false,
                expiresAt: suspData['expiresAt'],
                hoursRemaining: suspData['hoursRemaining'],
                appealStatus: suspData['appealStatus'] ?? 'none',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Fail open — let the user through if detection service is down
      }

      // Refresh profile from backend so avatar URL and data persist
      // across app reinstalls. Falls back to cached session on failure.
      try {
        final userId = session['id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          final auth = AuthService.instance;
          final fresh = await auth.getProfile(userId: userId);
          if (fresh.success && fresh.user != null) {
            await SessionManager.instance.saveSession(fresh.user!);
            await ChatThemeProvider.instance.syncPremiumFromSession(fresh.user!);
          }
        }
      } catch (_) {}

      if (!mounted) return;
      final profileCompleted = session['profileCompleted'] == true;
      if (profileCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KoraHomeScreen()),
        );
        // Background chat restore — non-blocking, runs after home loads
        final userEmail = session['email']?.toString() ?? '';
        if (userEmail.isNotEmpty) {
          ChatSyncService.instance.setUserEmail(userEmail);
          ChatSyncService.instance.setSenderName(
            session['fullName']?.toString() ?? '',
          );
          ChatSyncService.instance.restoreFromCloud().then((_) {
            ChatSyncService.instance.startPolling();
          });
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              email: email,
              userData: session,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Kora brand background — deep near-black
      backgroundColor: KoraColors.trueBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Square logo with shooting star orbit ──
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shooting star animation layer
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: ShootingStarPainter(_controller.value),
                      );
                    },
                  ),
                  // Square logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      gradient: KoraColors.brandGradient,
                      boxShadow: [
                        BoxShadow(
                          color: KoraColors.purple.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: Image.asset(
                        'assets/images/kora_logo_lockup.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Kora wordmark
            const Text(
              'Kora Messenger',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            Text(
              'Connect. Communicate. Create.',
              style: TextStyle(
                fontSize: 13,
                color: KoraColors.purple.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
