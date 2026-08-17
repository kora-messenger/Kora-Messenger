import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';

void main() {
  // ── Welcome Screen ──────────────────────────────────────────
  testWidgets('Welcome screen displays Kora branding and CTAs', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Terms & Privacy Policy'), findsOneWidget);
  });

  // ── Sign Up Screen ──────────────────────────────────────────
  testWidgets('Tapping Create Account navigates to Sign Up screen', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Join Kora and start connecting today.'), findsOneWidget);
  });

  testWidgets('Sign Up screen has all required fields', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Add Photo'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('Sign Up shows validation errors on empty submit', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Tap the Create Account button on the form
    await tester.tap(find.text('Create Account').last);
    await tester.pump();

    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please enter a username'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
  });

  // ── Log In Screen ───────────────────────────────────────────
  testWidgets('Tapping Log In navigates to Log In screen', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in to continue to Kora.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Log In screen has email and password fields', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
  });

  // ── Forgot Password ─────────────────────────────────────────
  testWidgets('Forgot Password screen opens from Log In', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
  });

  // ── Back Navigation ──────────────────────────────────────────
  testWidgets('Back button on Sign Up returns to Welcome screen', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
  });

  testWidgets('Back button on Log In returns to Welcome screen', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
  });
}
