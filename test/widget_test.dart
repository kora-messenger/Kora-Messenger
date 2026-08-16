import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';

void main() {
  testWidgets('Welcome screen displays correct elements', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    // Verify app title
    expect(find.text('Kora Messenger'), findsOneWidget);

    // Verify subtitle
    expect(
      find.text('Connect instantly. Chat seamlessly. Your conversations, elevated.'),
      findsOneWidget,
    );

    // Verify Sign Up button
    expect(find.text('Sign Up'), findsOneWidget);

    // Verify Log In button
    expect(find.text('Log In'), findsOneWidget);
  });
}
