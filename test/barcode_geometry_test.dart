import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/scan/code_scan_geometry.dart';

void main() {
  test('barcode decoding rectangle stays inside rounded guide at phone sizes', () {
    for (final width in [240.0,272.0,300.0]) {
      final frame=Rect.fromLTWH(24,120,width,width*.55);
      final geometry=BarcodeScanGeometry(frame);
      final roi=geometry.scanWindow;
      for (final p in [roi.topLeft,roi.topRight,roi.bottomLeft,roi.bottomRight]) {
        expect(geometry.opening.contains(p),isTrue);
        expect(geometry.stroke.contains(p),isTrue);
      }
      final paintedBounds=geometry.stroke.outerRect.inflate(BarcodeScanGeometry.strokeWidth/2);
      expect(paintedBounds,frame);
      expect(geometry.opening.contains(frame.topLeft),isFalse);
    }
  });
}
