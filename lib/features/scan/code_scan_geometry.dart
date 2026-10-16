import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One geometry source for the barcode mask, visible corners and decoder ROI.
class BarcodeScanGeometry {
  BarcodeScanGeometry(this.frame);
  final Rect frame;
  static const strokeWidth = 6.0;
  double get radius => math.min(20.0, frame.shortestSide / 4);
  RRect get opening => RRect.fromRectAndRadius(frame, Radius.circular(radius));
  RRect get stroke => RRect.fromRectAndRadius(
    frame.deflate(strokeWidth/2), Radius.circular(radius-strokeWidth/2));
  // Decoder ROI is rectangular. Insetting by the radius keeps all four ROI
  // corners inside the rounded opening, including the border's inner edge.
  Rect get scanWindow => frame.deflate(radius + strokeWidth/2);

  void paintCorners(Canvas canvas) {
    final rect=stroke.outerRect;
    final r=stroke.tlRadiusX;
    final length=math.min(30.0,rect.shortestSide/2);
    final paint=Paint()..color=const Color(0xFF5063FF)
      ..style=PaintingStyle.stroke..strokeWidth=strokeWidth
      ..strokeCap=StrokeCap.round;
    for (final corner in [rect.topLeft,rect.topRight,rect.bottomLeft,rect.bottomRight]) {
      canvas.save();
      canvas.translate(corner.dx,corner.dy);
      canvas.scale(corner.dx==rect.left ? 1.0 : -1.0,corner.dy==rect.top ? 1.0 : -1.0);
      final path=Path()..moveTo(0,length)..lineTo(0,r)
        ..arcToPoint(Offset(r,0),radius:Radius.circular(r))..lineTo(length,0);
      canvas.drawPath(path,paint);
      canvas.restore();
    }
  }
}
