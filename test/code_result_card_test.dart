import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/scan/code_scanner.dart';

void main() {
  for (final qr in [true, false]) {
    testWidgets('${qr ? 'QR' : 'Barcode'} result actions and long payload', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodeResultCard(
                qrOnly: qr,
                value: List.filled(100, 'long scanned payload').join(' '),
                onClose: () => calls.add('close'),
                onOpen: () => calls.add('open'),
                onCopy: () => calls.add('copy'),
                onSave: () => calls.add('save'),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(qr ? 'QR Code Detected' : 'Barcode Detected'),
        findsOneWidget,
      );
      for (final label in [qr ? 'Open' : 'Search', 'Copy', 'Save']) {
        await tester.tap(find.text(label));
      }
      await tester.tap(find.byTooltip('Scan again'));
      expect(calls, ['open', 'copy', 'save', 'close']);
      expect(tester.takeException(), isNull);
    });
  }
}
