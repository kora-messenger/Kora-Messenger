import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';
import 'package:kora_messenger/screens/profile_setup_screen.dart';
import 'package:kora_messenger/screens/kora_home_screen.dart';
import 'package:kora_messenger/models/chat_models.dart';
import 'package:kora_messenger/services/chat_service.dart';
import 'package:kora_messenger/screens/chat/kora_chat_screen.dart';

void main() {
  homeScreenTests();
  chatScreenTests();
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

// ── Home Screen ────────────────────────────────────────────────
void homeScreenTests() {
  group('Kora Home Screen', () {
    setUp(() {
      ChatService.instance.showEmptyState = false;
    });

    testWidgets('Chats tab shows Kora branding and header icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kora'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('Chats tab shows Kora Support and Kora AI Assistant with badges', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kora Support'), findsOneWidget);
      expect(find.text('Kora AI Assistant'), findsOneWidget);
      // Both are official accounts -> purple check badge icons present
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('Bottom navigation has all five sections', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Calls'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Tapping Profile in bottom nav switches to Profile tab', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Ijezie Goodluck'), findsOneWidget);
    });

    testWidgets('Empty state shows when there are no chats', (tester) async {
      ChatService.instance.showEmptyState = true;
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('Start a Chat'), findsOneWidget);

      ChatService.instance.showEmptyState = false;
    });

    testWidgets('Tapping search icon opens the search screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: KoraHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Search Kora'), findsOneWidget);
    });
  });
}

// ── Chat Screen ───────────────────────────────────────────────

void chatScreenTests() {
  group('Kora Chat Screen', () {
    testWidgets('Shows header with contact name and badge for Kora Support', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_support',
          name: 'Kora Support',
          avatarAsset: 'assets/images/kora_support_avatar.png',
          badge: KoraBadgeType.officialPurple,
          isOnline: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kora Support'), findsOneWidget);
      expect(find.text('online'), findsOneWidget);
    });

    testWidgets('Shows header with Kora AI Assistant name', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_ai',
          name: 'Kora AI Assistant',
          avatarAsset: 'assets/images/kora_ai_avatar.png',
          badge: KoraBadgeType.officialPurple,
          isOnline: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kora AI Assistant'), findsOneWidget);
    });

    testWidgets('Shows seeded messages for Kora Support', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_support',
          name: 'Kora Support',
          avatarAsset: 'assets/images/kora_support_avatar.png',
          badge: KoraBadgeType.officialPurple,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Kora Messenger! 👋'), findsOneWidget);
      expect(find.textContaining('I\'m here to help'), findsOneWidget);
    });

    testWidgets('Shows header action icons (call, video, menu)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_ai',
          name: 'Kora AI Assistant',
          badge: KoraBadgeType.officialPurple,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('Shows empty state for a conversation with no messages', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'new_empty_chat',
          name: 'Test User',
          badge: KoraBadgeType.none,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Say hi to Test User'), findsOneWidget);
    });

    testWidgets('Composer shows mic icon when empty and send icon when typing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_support',
          name: 'Kora Support',
          badge: KoraBadgeType.officialPurple,
        ),
      ));
      await tester.pumpAndSettle();

      // Initially shows mic
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);

      // Type text
      await tester.enterText(find.byType(TextField), 'Hello there');
      await tester.pumpAndSettle();

      // Now shows send
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('Tapping send adds a new message to the list', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: KoraChatScreen(
          chatId: 'kora_support',
          name: 'Kora Support',
          badge: KoraBadgeType.officialPurple,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message 123');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Test message 123'), findsOneWidget);
    });
  });
}
