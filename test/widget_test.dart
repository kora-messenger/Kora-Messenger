import 'package:flutter_test/flutter_test.dart';

import 'package:kora_messenger/main.dart';

void main() {
  testWidgets('Welcome screen displays Kora branding and CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(const KoraMessengerApp());

    // Headline
    expect(find.text('Welcome to Kora'), findsOneWidget);

    // Subtitle
    expect(
      find.text(
        'Real conversations, reimagined. Connect with the '
        'people who matter — instantly, and securely.',
      ),
      findsOneWidget,
    );

    // Primary CTA
    expect(find.text('Create Account'), findsOneWidget);

    // Secondary CTA
    expect(find.text('Log In'), findsOneWidget);

    // Legal text
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });
}
