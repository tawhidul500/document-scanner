import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/settings/settings_screen.dart';

void main() {
  testWidgets('settings opens language and About designs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(find.byType(Switch), findsNWidgets(2));
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('Choose App Language'), findsOneWidget);
    expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About App'), 200);
    await tester.tap(find.text('About App'));
    await tester.pumpAndSettle();
    expect(find.text('Version 0.4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
