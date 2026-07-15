import 'package:flutter_test/flutter_test.dart';
import 'package:axira/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (tester) async {
    await tester.pumpWidget(const AxiraApp());

    // Splash should show the logo text
    expect(find.text('AXIRA'), findsOneWidget);
    expect(find.text('Your Ultimate Gift Card Hub'), findsOneWidget);

    // Advance past the 3-second splash delay to clear pending timers
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Should have transitioned to onboarding
    expect(find.text('Buy & Sell Gift Cards'), findsOneWidget);
  });
}
