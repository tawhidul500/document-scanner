import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/id_card_processing.dart';

void main() {
  test('ID guide fits small and tall viewports and retains card ratio', () {
    for (final size in [
      [375.0, 574.0],
      [320.0, 300.0],
      [800.0, 350.0],
    ]) {
      final guide = idCardGuide(size[0], size[1]);
      expect(guide[0], greaterThanOrEqualTo(0));
      expect(guide[1], greaterThanOrEqualTo(0));
      expect(guide[0] + guide[2], lessThanOrEqualTo(size[0]));
      expect(guide[1] + guide[3], lessThanOrEqualTo(size[1]));
      expect(guide[2] / guide[3], closeTo(85.6 / 54, .001));
    }
  });

  test(
    'camera crop matches the guide rather than exporting the full frame',
    () {
      final image = img.Image(width: 600, height: 800);
      img.fill(image, color: img.ColorRgb8(90, 140, 190));
      final bytes = processIdCardCapture({
        'bytes': Uint8List.fromList(img.encodePng(image)),
        'width': 375.0,
        'height': 574.0,
      });
      final crop = img.decodeImage(bytes)!;
      expect(crop.width, lessThan(image.width));
      expect(crop.height, lessThan(image.height));
      expect(crop.width / crop.height, closeTo(85.6 / 54, .02));
      expect(
        crop.getPixel(crop.width ~/ 2, crop.height ~/ 2).g,
        closeTo(140, 3),
      );
    },
  );

  test('front and back are saved on exactly one PDF page', () async {
    final directory = await Directory.systemTemp.createTemp('id_card_pdf_');
    try {
      final paths = <String>[];
      for (final value in [80, 180]) {
        final image = img.Image(width: 160, height: 100);
        img.fill(image, color: img.ColorRgb8(value, value, value));
        final file = File('${directory.path}/$value.png');
        await file.writeAsBytes(img.encodePng(image));
        paths.add(file.path);
      }
      final pdf = await buildIdCardPdf(paths);
      expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
      final source = latin1.decode(pdf);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(source).length, 1);
      await expectLater(buildIdCardPdf([]), throwsFormatException);
      await expectLater(
        buildIdCardPdf([...paths, paths.first]),
        throwsFormatException,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
