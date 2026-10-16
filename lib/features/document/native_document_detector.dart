import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart' as native;

import 'edge_detector.dart';

/// Headless native engine: the app continues to own the camera and all UI.
class NativeDocumentDetector {
  NativeDocumentDetector({native.DocumentDetector? detector})
      : _detector = detector ?? native.DocumentDetector();
  final native.DocumentDetector _detector;

  Future<DocumentQuad?> detectFrame(CameraImage frame, int rotation) async {
    final native.ScanInput input;
    if (frame.format.group == ImageFormatGroup.bgra8888 && frame.planes.isNotEmpty) {
      final plane = frame.planes.first;
      input = native.ScanInput.bgraFrame(
        width: frame.width, height: frame.height, rotation: rotation,
        bytes: plane.bytes, bytesPerRow: plane.bytesPerRow,
      );
    } else if (frame.format.group == ImageFormatGroup.yuv420 && frame.planes.length >= 3) {
      input = native.ScanInput.yuvFrame(
        width: frame.width, height: frame.height, rotation: rotation,
        yBytes: frame.planes[0].bytes,
        uBytes: frame.planes[1].bytes,
        vBytes: frame.planes[2].bytes,
        yRowStride: frame.planes[0].bytesPerRow,
        uvRowStride: frame.planes[1].bytesPerRow,
        uvPixelStride: frame.planes[1].bytesPerPixel ?? 1,
      );
    } else {
      return null; // Unsupported frames never invent document edges.
    }
    return _quad(await _detector.detect(input,
      sensitivity: native.DetectionSensitivity.balanced), live: true);
  }

  Future<DocumentQuad?> detectFile(String path) async => _quad(
    await _detector.detect(native.ScanInput.file(path),
      sensitivity: native.DetectionSensitivity.balanced), live: false);

  DocumentQuad? _quad(native.DocumentCorners? corners, {required bool live}) {
    if (corners == null || !corners.isConvex) return null;
    final q = DocumentQuad(corners.toList()
      .map((p) => math.Point<double>(p.x, p.y)).toList());
    if (!validDocumentQuad(q, live: live)) return null;
    return q;
  }
}

/// Clockwise rotation to match the portrait-up camera preview. AVCapture's
/// portrait buffers are already upright; landscape buffers need sensor rotation.
int portraitFrameRotation({required bool ios, required int width,
    required int height, required int sensorOrientation}) {
  if (ios && height >= width) return 0;
  return ((sensorOrientation % 360) + 360) % 360;
}

bool validDocumentQuad(DocumentQuad quad, {bool live = true}) {
  if (quad.points.length != 4 || quad.points.any((p) =>
      !p.x.isFinite || !p.y.isFinite || p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1)) {
    return false;
  }
  if (quad.area < (live ? .12 : .03) || quad.area > (live ? .95 : 1.0)) return false;
  for (var i = 0; i < 4; i++) {
    final a = quad.points[i], b = quad.points[(i + 1) % 4], c = quad.points[(i + 2) % 4];
    if ((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) <= 0) return false;
  }
  return true;
}

/// Smooth only the visual outline. Auto capture always evaluates raw corners,
/// so smoothing cannot disguise hand movement and trigger a blurry capture.
class DocumentOutlineSmoother {
  DocumentQuad? _previous;
  void reset() => _previous = null;
  DocumentQuad? add(DocumentQuad? current) {
    if (current == null) { reset(); return null; }
    final previous = _previous;
    if (previous == null || previous.distance(current) > .12) {
      return _previous = current;
    }
    return _previous = DocumentQuad(List.generate(4, (i) => math.Point(
      previous.points[i].x * .55 + current.points[i].x * .45,
      previous.points[i].y * .55 + current.points[i].y * .45,
    )));
  }
}
