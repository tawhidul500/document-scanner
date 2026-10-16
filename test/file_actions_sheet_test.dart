import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/file_actions_sheet.dart';
import 'package:pdf_scanner/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('file options scroll at large text in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      String? result;
      final document = ScanFile(id: '1_a', name: 'A saved QR code',
          kind: ScanKind.qr, extension: 'txt', created: DateTime(2026), bytes: 12);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppThemes.dark : AppThemes.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () async { result = await showFileActions(context, document); },
          child: const Text('Open file'),
        ))),
      ));
      await tester.tap(find.text('Open file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your text file is kept.'), findsOneWidget);
      await tester.ensureVisible(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(result, 'Export');
      expect(tester.takeException(), isNull);
    });
  }
}
