import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/edge_detector.dart';
import 'package:pdf_scanner/features/document/page_processing.dart';

void main() {
  test('detects an inset page and rejects a featureless frame', () {
    const w = 200, h = 280;
    final gray = Uint8List(w * h);
    for (var y = 35; y < 245; y++) {
      for (var x = 30; x < 170; x++) gray[y * w + x] = 235;
    }
    final q = detectDocument({'gray': gray, 'width': w, 'height': h});
    expect(q, isNotNull);
    expect(q!.points.first.x, closeTo(30 / 199, 0.03));
    expect(q.points.first.y, closeTo(35 / 279, 0.03));
    expect(
      detectDocument({'gray': Uint8List(w * h), 'width': w, 'height': h}),
      isNull,
    );
  });
  test(
    'automatic capture requires stability and page removal before repeat',
    () {
      const q = DocumentQuad([
        Point(0.1, 0.1),
        Point(0.9, 0.1),
        Point(0.9, 0.9),
        Point(0.1, 0.9),
      ]);
      final gate = AutoCaptureGate();
      final time = DateTime(2026);
      expect(gate.update(q, time), isFalse);
      expect(
        gate.update(q, time.add(const Duration(milliseconds: 1100))),
        isFalse,
      );
      expect(
        gate.update(q, time.add(const Duration(milliseconds: 1200))),
        isTrue,
      );
      gate.captured();
      expect(gate.update(q, time.add(const Duration(seconds: 5))), isFalse);
      for (var i = 0; i < 3; i++)
        gate.update(null, time.add(Duration(seconds: 6 + i)));
      expect(gate.update(q, time.add(const Duration(seconds: 9))), isFalse);
      expect(gate.update(q, time.add(const Duration(seconds: 11))), isTrue);
    },
  );
  test('camera motion restarts the stability interval', () {
    const a = DocumentQuad([
      Point(0.1, 0.1),
      Point(0.8, 0.1),
      Point(0.8, 0.8),
      Point(0.1, 0.8),
    ]);
    const b = DocumentQuad([
      Point(0.2, 0.1),
      Point(0.9, 0.1),
      Point(0.9, 0.8),
      Point(0.2, 0.8),
    ]);
    final gate = AutoCaptureGate(), t = DateTime(2026);
    gate.update(a, t);
    expect(gate.update(b, t.add(const Duration(seconds: 2))), isFalse);
    expect(gate.update(b, t.add(const Duration(seconds: 3))), isFalse);
  });
  test(
    'rotation swaps page dimensions and PDF output has a PDF header',
    () async {
      final source = img.Image(width: 60, height: 100);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));
      final bytes = Uint8List.fromList(img.encodeJpg(source));
      final rotated = processPage({'bytes': bytes, 'rotate': true});
      final decoded = img.decodeJpg(rotated)!;
      expect(decoded.width, 100);
      expect(decoded.height, 60);
      final pdf = await buildDocumentPdf([bytes, rotated]);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    },
  );
}
