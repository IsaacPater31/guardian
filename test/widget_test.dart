// Placeholder widget test for the Guardian app.
// Replace this with real integration/widget tests as the app grows.

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/main.dart';

void main() {
  testWidgets('GuardianApp renders without throwing', (WidgetTester tester) async {
    // Smoke test: ensure the root widget can be built.
    // Full Firebase initialisation is skipped in unit tests;
    // use integration_test for end-to-end flows.
    expect(() => const GuardianApp(), returnsNormally);
  });
}
