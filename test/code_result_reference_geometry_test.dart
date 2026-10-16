import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/scan/code_result_screen.dart';
import 'package:pdf_scanner/theme/app_theme.dart';

// Read dimensions from the supplied SVG, not from the implementation constants.
Rect svgRect(String source, String id) {
  final tag = RegExp('<rect[^>]*id="$id"[^>]*>').firstMatch(source)!.group(0)!;
  double value(String attribute) => double.parse(
    RegExp('\\b$attribute="([0-9.]+)"').firstMatch(tag)!.group(1)!);
  return Rect.fromLTWH(value('x'), value('y'), value('width'), value('height'));
}

Rect svgAction(String source, String id) {
  final group = source.split('<g id="$id"')[1];
  final rect = RegExp('<rect[^>]*>').firstMatch(group)!.group(0)!;
  double value(String attribute) => double.parse(
    RegExp('\\b$attribute="([0-9.]+)"').firstMatch(rect)!.group(1)!);
  return Rect.fromLTWH(value('x'), value('y'), value('width'), value('height'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
  });

  for (final qr in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets('reference ${qr ? 'QR' : 'barcode'} bounds and baselines in ${dark ? 'dark' : 'light'}',
        (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final name = qr ? 'QR-Code_page_redesign.svg' : 'Barcode_page_redesign.svg';
        final svg = File('design/scan_results/$name').readAsStringSync();
        await tester.pumpWidget(MaterialApp(theme: dark ? AppThemes.dark : AppThemes.light,
          home: CodeResultScreen(qrOnly: qr,
            value: qr ? 'https://www.qrcodesaustralia.com.au/' : '5901234123457',
            formatLabel: 'EAN-13', onClose: () {}, onOpen: () {}, onCopy: () {},
            onSave: () {}, onPromotion: () {})));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(const ValueKey('code-result-card'))),
          svgRect(svg, 'Card_BG'));
        expect(tester.getRect(find.byKey(const ValueKey('code-result-preview'))),
          svgRect(svg, 'Text_Preview_BG'));
        for (final action in [qr ? 'open' : 'search', 'copy', 'save']) {
          final id = '${action[0].toUpperCase()}${action.substring(1)}_Button';
          expect(tester.getRect(find.byKey(ValueKey('reference-$action-button'))),
            svgAction(svg, id));
        }
        // Every element inside Promo_Body inherits its translate(0 22).
        expect(tester.getRect(find.byKey(const ValueKey('reference-store-button'))),
          svgRect(svg, 'CTA_BG').shift(const Offset(0, 22)));
        for (final pair in [
          ('Title', qr ? 'QR Code Detected' : 'Barcode Detected'),
          ('Headline_1', 'Make your own'), ('Headline_2', 'QR & Barcodes'),
          ('Subtext', 'Create, customize and share in seconds.'),
        ]) {
          final tag = RegExp('<text[^>]*id="${pair.$1}"[^>]*>').firstMatch(svg)!.group(0)!;
          final baseline = double.parse(RegExp('\\by="([0-9.]+)"').firstMatch(tag)!.group(1)!);
          final rich = find.descendant(of: find.text(pair.$2), matching: find.byType(RichText));
          final paragraph = tester.renderObject<RenderParagraph>(rich);
          final actual = paragraph.localToGlobal(Offset(0,
            paragraph.getDryBaseline(paragraph.constraints,
                TextBaseline.alphabetic)!)).dy;
          expect(actual, closeTo(baseline + (pair.$1 == 'Title' ? 0 : 22), .01));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('extra top inset keeps the reference controls below a notch', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppThemes.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 44)),
        child: child!),
      home: CodeResultScreen(qrOnly: true, value: 'hello', onClose: () {},
        onOpen: () {}, onCopy: () {}, onSave: () {}, onPromotion: () {})));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('code-result-card'))).dy, 104);
    expect(tester.takeException(), isNull);
  });
}
