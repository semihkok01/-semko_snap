import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semkosnap_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('zeigt den Login beim Start', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SemkoScanApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Semko Scan'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Anmelden'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Registrieren'), findsOneWidget);
  });
}
