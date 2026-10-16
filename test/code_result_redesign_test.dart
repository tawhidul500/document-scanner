import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf_scanner/features/scan/code_result_actions.dart';
import 'package:pdf_scanner/features/scan/code_result_screen.dart';
import 'package:pdf_scanner/theme/app_theme.dart';

void main() {
  test('barcode search encodes the exact payload as one query parameter', () {
    const payload = 'A&B #12 / +? বাংলা';
    final uri = codeResultUri(qrOnly: false, value: payload)!;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters, {'q': payload});
    expect(uri.fragment, isEmpty);
  });

  test('QR open allows web links while preserving non-link data', () {
    const link = 'https://example.org/পথ?q=one&lang=bn#result';
    expect(codeResultUri(qrOnly: true, value: ' $link '), Uri.parse(link));
    for (final payload in ['', 'hello', 'WIFI:S:Home;T:WPA;P:password;;',
      'BEGIN:VCARD\nFN:Sam\nEND:VCARD', 'javascript:alert(1)',
      'file:///etc/passwd', 'https:///']) {
      expect(codeResultUri(qrOnly: true, value: payload), isNull);
    }
  });

  test('format badges describe the decoder result, not the SVG sample', () {
    final formats = {
      BarcodeFormat.ean13: 'EAN-13', BarcodeFormat.ean8: 'EAN-8',
      BarcodeFormat.code128: 'CODE 128', BarcodeFormat.code39: 'CODE 39',
      BarcodeFormat.code93: 'CODE 93', BarcodeFormat.codabar: 'CODABAR',
      BarcodeFormat.itf14: 'ITF-14', BarcodeFormat.upcA: 'UPC-A',
      BarcodeFormat.upcE: 'UPC-E', BarcodeFormat.pdf417: 'PDF417',
      BarcodeFormat.dataMatrix: 'DATA MATRIX', BarcodeFormat.aztec: 'AZTEC',
    };
    for (final entry in formats.entries) {
      expect(barcodeFormatLabel(entry.key), entry.value);
    }
    expect(barcodeFormatLabel(null), 'Barcode');
  });

  test('promotion requires a configured secure destination', () {
    expect(generatorAppUri(''), isNull);
    expect(generatorAppUri('market://details?id=example'), isNull);
    expect(generatorAppUri('https://play.google.com/store/apps/details?id=test'),
      Uri.parse('https://play.google.com/store/apps/details?id=test'));
  });

  for (final dark in [false, true]) {
    for (final qr in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'} ${qr ? 'QR' : 'barcode'} result actions', (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        final value = qr ? 'https://example.org/result' : '5901234123457';
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppThemes.dark : AppThemes.light,
          home: CodeResultScreen(qrOnly: qr, value: value, formatLabel: 'EAN-13',
            onClose: () => calls.add('close'), onOpen: () => calls.add('open'),
            onCopy: () => calls.add('copy'), onSave: () => calls.add('save'),
            onPromotion: () => calls.add('promotion')),
        ));
        await tester.pumpAndSettle();
        expect(find.text(value), findsOneWidget);
        expect(find.byKey(const ValueKey('barcode-format')),
          qr ? findsNothing : findsOneWidget);
        final preview = tester.widget<Container>(find.byKey(const ValueKey('code-result-preview')));
        expect((preview.decoration! as BoxDecoration).color, dark
          ? CodeResultColors(true).preview
          : const Color(0xFF1B1F6B).withValues(alpha: .35));
        final card = tester.getSize(find.byKey(const ValueKey('code-result-card')));
        expect(card.width, 343);
        for (final label in [qr ? 'Open' : 'Search', 'Copy', 'Save']) {
          await tester.tap(find.text(label));
        }
        await tester.tap(find.byTooltip('Scan again'));
        await tester.tap(find.byTooltip('Back to scanner'));
        await tester.ensureVisible(find.text('Google Play'));
        await tester.tap(find.text('Google Play'));
        expect(calls, ['open', 'copy', 'save', 'close', 'close', 'promotion']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 430.0]) {
    for (final qr in [false, true]) {
      testWidgets('long ${qr ? 'QR' : 'barcode'} at width $width with large text remains usable', (tester) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var saved = false;
        await tester.pumpWidget(MaterialApp(theme: AppThemes.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
            child: child!),
          home: CodeResultScreen(qrOnly: qr,
            value: List.filled(150, 'long-value-0123456789').join(),
            formatLabel: 'DATA MATRIX', onClose: () {}, onOpen: () {},
            onCopy: () {}, onSave: () => saved = true, onPromotion: () {}),
        ));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        expect(saved, isTrue);
        await tester.ensureVisible(find.text('Google Play'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
