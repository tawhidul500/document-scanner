import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/document/recognize_text.dart';

void main() {
  Widget screen(Future<String> Function(String) recognize) => MaterialApp(
    home: RecognizeTextScreen(
      path: 'test-page.jpg',
      store: DocumentStore(Directory('unused-ocr-test-directory')),
      recognize: recognize,
    ),
  );

  testWidgets('recognized text is editable and Save opens the PDF dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen((_) async => 'Dear William David\n\nRecognized content.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recognize Text'), findsOneWidget);
    expect(
      find.text('Dear William David\n\nRecognized content.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Corrected content.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Enter File Name'), findsOneWidget);
    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Corrected content.'), findsOneWidget);
  });

  testWidgets('empty recognition disables Save', (tester) async {
    await tester.pumpWidget(screen((_) async => ''));
    await tester.pumpAndSettle();
    expect(
      find.text('No text found. Try a clearer, well-lit scan.'),
      findsOneWidget,
    );
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('recognition failure can be retried', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      screen((_) async {
        if (attempts++ == 0) throw const FormatException('Unreadable');
        return 'Recovered text';
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered text'), findsOneWidget);
    expect(attempts, 2);
  });

  test(
    'named PDF creation validates before writing and survives reload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recognized_pdf_test_',
      );
      try {
        final store = DocumentStore(directory);
        await expectLater(
          store.addBytes(
            [1, 2, 3],
            ScanKind.document,
            'pdf',
            name: '../invalid',
          ),
          throwsFormatException,
        );
        expect(await directory.list().isEmpty, isTrue);
        final document = await store.addBytes(
          [1, 2, 3],
          ScanKind.document,
          'pdf',
          name: 'Recognized letter',
        );
        expect(document.filename, 'Recognized letter.pdf');
        final restored = DocumentStore(directory);
        await restored.load();
        expect(restored.files.single.name, 'Recognized letter');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
