import 'dart:math' as math;
import 'dart:typed_data';

/// Normalized clockwise corners: top-left, top-right, bottom-right, bottom-left.
class DocumentQuad {
  const DocumentQuad(this.points);
  final List<math.Point<double>> points;
  double distance(DocumentQuad other) {
    var maximum = 0.0;
    for (var i = 0; i < 4; i++) {
      maximum = math.max(maximum, points[i].distanceTo(other.points[i]));
    }
    return maximum;
  }
}

/// Conservative contour detector. No rectangle is invented when no contour fits.
/// Input is a small upright luminance plane; work runs off the UI isolate.
DocumentQuad? detectDocument(Map<String, Object> frame) {
  final gray = frame['gray'] as Uint8List;
  final w = frame['width'] as int, h = frame['height'] as int;
  if (w < 12 || h < 12 || gray.length != w * h) return null;
  final edges = Uint8List(w * h);
  for (var y = 2; y < h - 2; y++) {
    for (var x = 2; x < w - 2; x++) {
      final p = y * w + x;
      final gx =
          -gray[p - w - 1] -
          2 * gray[p - 1] -
          gray[p + w - 1] +
          gray[p - w + 1] +
          2 * gray[p + 1] +
          gray[p + w + 1];
      final gy =
          -gray[p - w - 1] -
          2 * gray[p - w] -
          gray[p - w + 1] +
          gray[p + w - 1] +
          2 * gray[p + w] +
          gray[p + w + 1];
      if (gx.abs() + gy.abs() > 150) edges[p] = 1;
    }
  }
  final joined = Uint8List(w * h);
  for (var y = 2; y < h - 2; y++) {
    for (var x = 2; x < w - 2; x++) {
      if (edges[y * w + x] == 0) continue;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) joined[(y + dy) * w + x + dx] = 1;
      }
    }
  }
  DocumentQuad? best;
  var bestArea = 0.0;
  for (var seed = 0; seed < joined.length; seed++) {
    if (joined[seed] != 1) continue;
    final queue = <int>[seed];
    joined[seed] = 0;
    var tl = math.Point<double>(w.toDouble(), h.toDouble());
    var tr = math.Point<double>(0, h.toDouble());
    var br = const math.Point<double>(0, 0);
    var bl = math.Point<double>(w.toDouble(), 0);
    for (var head = 0; head < queue.length; head++) {
      final pos = queue[head], x = pos % w, y = pos ~/ w;
      final pt = math.Point<double>(x.toDouble(), y.toDouble());
      if (x + y < tl.x + tl.y) tl = pt;
      if (x - y > tr.x - tr.y) tr = pt;
      if (x + y > br.x + br.y) br = pt;
      if (x - y < bl.x - bl.y) bl = pt;
      for (final n in [pos - 1, pos + 1, pos - w, pos + w]) {
        if (n >= 0 &&
            n < joined.length &&
            joined[n] == 1 &&
            (n % w - x).abs() <= 1) {
          joined[n] = 0;
          queue.add(n);
        }
      }
    }
    if (queue.length < (w + h) ~/ 2) continue;
    final points = [tl, tr, br, bl];
    var area = 0.0;
    var valid = true;
    for (var i = 0; i < 4; i++) {
      final a = points[i], b = points[(i + 1) % 4], c = points[(i + 2) % 4];
      area += a.x * b.y - b.x * a.y;
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross <= 0 ||
          a.distanceTo(b) < math.min(w, h) * 0.18 ||
          a.x < 4 ||
          a.y < 4 ||
          a.x > w - 5 ||
          a.y > h - 5)
        valid = false;
      // Each inferred side must be supported by actual nearby edge pixels.
      var supported = 0;
      for (var k = 0; k < 30; k++) {
        final t = k / 29;
        final sx = (a.x + (b.x - a.x) * t).round();
        final sy = (a.y + (b.y - a.y) * t).round();
        var found = false;
        for (var dy = -3; dy <= 3; dy++) {
          for (var dx = -3; dx <= 3; dx++) {
            final ex = sx + dx, ey = sy + dy;
            if (ex >= 0 &&
                ey >= 0 &&
                ex < w &&
                ey < h &&
                edges[ey * w + ex] == 1)
              found = true;
          }
        }
        if (found) supported++;
      }
      if (supported < 22) valid = false;
    }
    area = area.abs() / 2;
    if (!valid ||
        area < w * h * 0.18 ||
        area > w * h * 0.92 ||
        area <= bestArea)
      continue;
    bestArea = area;
    best = DocumentQuad(
      points.map((p) => math.Point(p.x / (w - 1), p.y / (h - 1))).toList(),
    );
  }
  return best;
}

class AutoCaptureGate {
  DocumentQuad? anchor;
  DateTime? stableSince;
  bool awaitingRemoval = false;
  int missingFrames = 0;
  void reset() {
    anchor = null;
    stableSince = null;
    missingFrames = 0;
  }

  void captured() {
    reset();
    awaitingRemoval = true;
  }

  bool update(DocumentQuad? quad, DateTime now) {
    if (quad == null) {
      anchor = null;
      stableSince = null;
      if (++missingFrames >= 3) awaitingRemoval = false;
      return false;
    }
    missingFrames = 0;
    if (awaitingRemoval) return false;
    if (anchor == null || anchor!.distance(quad) > 0.025) {
      anchor = quad;
      stableSince = now;
      return false;
    }
    return now.difference(stableSince!).inMilliseconds >= 1200;
  }
}
