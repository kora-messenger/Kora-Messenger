import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';
import 'package:kora_messenger/screens/profile_setup_screen.dart';

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
  testWidgets('Back button on Log In returns to Welcome screen', (tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
  });

  // ── Profile Setup Screen ────────────────────────────────────
  testWidgets('Profile Setup displays heading and description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
          userData: {'fullName': 'Test User', 'username': 'testuser'},
        ),
      ),
    );

    expect(find.text('Set Up Your Profile'), findsOneWidget);
    expect(
      find.text('Tell people a little about you. You can change these details later in Settings.'),
      findsOneWidget,
    );
  });

  testWidgets('Profile Setup has all required and optional fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
        ),
      ),
    );

    expect(find.text('Full Name'), findsWidgets);
    expect(find.text('Username'), findsWidgets);
    expect(find.text('Kora ID'), findsOneWidget);
    expect(find.text('Bio'), findsNWidgets(2));
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Profile Setup shows required and optional indicators', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
        ),
      ),
    );

    // Required fields have asterisk
    expect(find.text('*'), findsNWidgets(2)); // Full Name + Username
    // Optional fields have (optional)
    expect(find.text('(optional)'), findsNWidgets(2)); // Kora ID + Bio
  });

  testWidgets('Profile Setup pre-fills name and username from userData', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
          userData: {'fullName': 'Goodluck Ijezie', 'username': 'goodluck'},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The pre-filled name should appear in the text field
    expect(find.text('Goodluck Ijezie'), findsOneWidget);
  });

  testWidgets('Profile Setup displays Kora ID in KM-XXXXXXXXX format', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
        ),
      ),
    );

    // Find text matching KM- followed by digits
    final koraIdFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^KM-\d{9}$').hasMatch(widget.data!),
    );
    expect(koraIdFinder, findsOneWidget);
  });

  testWidgets('Profile Setup shows default avatar when no photo selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
        ),
      ),
    );

    // Should show "Add Photo" text when no photo
    expect(find.text('Add Photo'), findsOneWidget);
  });

  testWidgets('Profile Setup shows username availability info text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
          userData: {'fullName': 'Test', 'username': 'testuser'},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 'testuser' is in the taken list, so it should show "already taken"
    expect(find.text('This username is already taken'), findsOneWidget);
  });

  testWidgets('Profile Setup shows unique identity text for Kora ID', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(
          email: 'test@example.com',
        ),
      ),
    );

    expect(find.text('Your unique identity on Kora'), findsOneWidget);
    expect(
      find.text('Others can find and connect with you using this ID.'),
      findsOneWidget,
    );
  });
}
