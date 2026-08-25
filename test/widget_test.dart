import 'package:flutter_test/flutter_test.dart';
import 'package:my_demo_project/main.dart';

void main() {
  testWidgets('Employee Portal initial render test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EmployeePortalApp());

    // Verify that login screen is displayed.
    expect(find.text('Employee Portal'), findsOneWidget);
    expect(find.text('LOGIN VIA SSO'), findsOneWidget);
  });
}
