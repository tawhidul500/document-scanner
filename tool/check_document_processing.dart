import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../lib/features/document/edge_detector.dart';
import '../lib/features/document/page_processing.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  const w = 200, h = 280;
  final gray = Uint8List(w * h);
  for (var y = 35; y < 245; y++) {
    for (var x = 30; x < 170; x++) {
      gray[y * w + x] = 235;
    }
  }
  final q = detectDocument({'gray': gray, 'width': w, 'height': h});
  check(q != null, 'Page not detected');
  check((q!.points.first.x - 30 / 199).abs() < 0.03, 'Corner mismatch');
  check(
    detectDocument({'gray': Uint8List(w * h), 'width': w, 'height': h}) == null,
    'Blank detected',
  );
  final gate = AutoCaptureGate(), now = DateTime(2026);
  check(!gate.update(q, now), 'Premature capture');
  check(
    !gate.update(q, now.add(const Duration(milliseconds: 1100))),
    'Early capture',
  );
  check(
    gate.update(q, now.add(const Duration(milliseconds: 1200))),
    'No stable capture',
  );
  gate.captured();
  check(
    !gate.update(q, now.add(const Duration(seconds: 5))),
    'Duplicate capture',
  );
  for (var i = 0; i < 3; i++) {
    gate.update(null, now.add(Duration(seconds: 6 + i)));
  }
  check(
    !gate.update(q, now.add(const Duration(seconds: 9))),
    'No settling time',
  );
  check(gate.update(q, now.add(const Duration(seconds: 11))), 'Did not rearm');
  final source = img.Image(width: 60, height: 100);
  img.fill(source, color: img.ColorRgb8(255, 255, 255));
  final bytes = Uint8List.fromList(img.encodeJpg(source));
  final rotated = processPage({'bytes': bytes, 'rotate': true});
  final decoded = img.decodeJpg(rotated)!;
  check(decoded.width == 100 && decoded.height == 60, 'Bad rotation');
  final cropped = processPage({
    'bytes': bytes,
    'corners': <double>[.1, .1, .9, .1, .9, .9, .1, .9],
  });
  check(img.decodeJpg(cropped)!.width < 60, 'Bad crop');
  final signed = processPage({
    'bytes': bytes,
    'strokes': <List<double>>[
      [.2, .2, .7, .7],
    ],
  });
  check(img.decodeJpg(signed) != null, 'Bad signature');
  final pdf = await buildDocumentPdf([bytes, rotated]);
  check(String.fromCharCodes(pdf.take(5)) == '%PDF-', 'Bad PDF');
  print(
    'PASS: contour + blank rejection, stable timing, duplicate prevention, rearm, rotation, crop, signature, PDF creation.',
  );
}
