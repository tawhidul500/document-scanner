import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/document/edge_detector.dart';
import 'package:pdf_scanner/features/document/native_document_detector.dart';

DocumentQuad rectangle(double x, double y, double width, double height) =>
    DocumentQuad([Point(x, y), Point(x + width, y),
      Point(x + width, y + height), Point(x, y + height)]);

void main() {
  test('portrait frames honor Android sensor rotation and upright iOS buffers', () {
    for (final angle in [0, 90, 180, 270]) {
      expect(portraitFrameRotation(ios: false, width: 1280, height: 720,
        sensorOrientation: angle), angle);
    }
    expect(portraitFrameRotation(ios: true, width: 720, height: 1280,
      sensorOrientation: 90), 0);
    expect(portraitFrameRotation(ios: true, width: 1280, height: 720,
      sensorOrientation: 90), 90);
  });

  test('reject tiny, crossed, clipped and nonfinite live quadrilaterals', () {
    expect(validDocumentQuad(rectangle(.1, .1, .8, .8)), isTrue);
    expect(validDocumentQuad(rectangle(.1, .1, .1, .1)), isFalse);
    expect(validDocumentQuad(rectangle(0, 0, 1, 1)), isFalse);
    expect(validDocumentQuad(rectangle(-.1, .1, .8, .8)), isFalse);
    expect(validDocumentQuad(rectangle(double.nan, .1, .8, .8)), isFalse);
    expect(validDocumentQuad(const DocumentQuad([
      Point(.1, .1), Point(.9, .9), Point(.9, .1), Point(.1, .9),
    ])), isFalse);
    // A user-selected still can legitimately fill the photograph.
    expect(validDocumentQuad(rectangle(0, 0, 1, 1), live: false), isTrue);
  });

  test('outline smooths jitter, snaps to new pages and clears missing detections', () {
    final smoother = DocumentOutlineSmoother();
    final first = rectangle(.1, .1, .6, .7);
    expect(smoother.add(first), same(first));
    final jitter = rectangle(.12, .1, .6, .7);
    final displayed = smoother.add(jitter)!;
    expect(displayed.points.first.x, greaterThan(.1));
    expect(displayed.points.first.x, lessThan(.12));
    final moved = rectangle(.3, .1, .6, .7);
    expect(smoother.add(moved), same(moved));
    expect(smoother.add(null), isNull);
    expect(smoother.add(first), same(first));
  });

  test('raw motion restarts auto-capture even while the overlay is smoothed', () {
    final smoother = DocumentOutlineSmoother(), gate = AutoCaptureGate();
    final start = DateTime(2026);
    final a = rectangle(.1, .1, .6, .7);
    final b = rectangle(.14, .1, .6, .7);
    smoother.add(a);
    gate.update(a, start);
    // Smoothing reduces the visible movement below the stability tolerance.
    expect(smoother.add(b)!.distance(a), lessThan(.025));
    expect(gate.update(b, start.add(const Duration(seconds: 2))), isFalse);
    expect(gate.update(b, start.add(const Duration(milliseconds: 3200))), isTrue);
  });
}
