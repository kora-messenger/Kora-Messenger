import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';

void main() {
  testWidgets('Welcome screen displays Kora branding and CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Terms & Privacy Policy'), findsOneWidget);
  });

  testWidgets('Tapping Create Account navigates to Sign Up screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Join Kora and start connecting today.'), findsOneWidget);
  });

  testWidgets('Tapping Log In navigates to Log In screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in to continue to Kora.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Sign Up screen has name, email, and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
  });

  testWidgets('Back button on Sign Up returns to Welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    // Tap the back arrow IconButton
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Connect with anyone, anywhere, anytime.'), findsOneWidget);
  });
}
