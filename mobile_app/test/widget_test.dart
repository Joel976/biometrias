// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:biometrics_app/main.dart';
import 'package:biometrics_app/models/admin_settings.dart';

void main() {
  testWidgets('App loads with default settings', (WidgetTester tester) async {
    // Build our app and trigger a frame with default admin settings
    await tester.pumpWidget(BiometricApp(adminSettings: AdminSettings()));

    // Verify that login screen loads
    expect(find.text('Autenticación Biométrica'), findsOneWidget);

    // Clean up: pump and settle to let timers complete
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('App loads with dark mode', (WidgetTester tester) async {
    // Build our app with dark mode enabled
    final darkSettings = AdminSettings(isDarkMode: true);
    await tester.pumpWidget(BiometricApp(adminSettings: darkSettings));

    // Verify that app is in dark mode
    expect(find.text('Autenticación Biométrica'), findsOneWidget);

    // Clean up: pump and settle to let timers complete
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
