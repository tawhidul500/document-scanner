import 'dart:math' as math;
import 'dart:typed_data';

/// Normalized clockwise corners: top-left, top-right, bottom-right, bottom-left.
class DocumentQuad {
  const DocumentQuad(this.points);
  final List<math.Point<double>> points;
  double get area {
    var total = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = points[i], b = points[(i+1)%4];
      total += a.x*b.y - b.x*a.y;
    }
    return total.abs()/2;
  }
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
  // A small binomial blur suppresses sensor noise without erasing page edges.
  final smooth = Uint8List(gray.length);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final p = y * w + x;
      smooth[p] = ((gray[p] * 4 +
        (gray[p-1] + gray[p+1] + gray[p-w] + gray[p+w]) * 2 +
        gray[p-w-1] + gray[p-w+1] + gray[p+w-1] + gray[p+w+1]) / 16).round();
    }
  }
  final magnitude = Uint16List(w * h);
  var sum = 0.0;
  for (var y = 2; y < h - 2; y++) {
    for (var x = 2; x < w - 2; x++) {
      final p = y * w + x;
      final gx = -smooth[p-w-1] - 2*smooth[p-1] - smooth[p+w-1]
        + smooth[p-w+1] + 2*smooth[p+1] + smooth[p+w+1];
      final gy = -smooth[p-w-1] - 2*smooth[p-w] - smooth[p-w+1]
        + smooth[p+w-1] + 2*smooth[p+w] + smooth[p+w+1];
      magnitude[p] = gx.abs() + gy.abs();
      sum += magnitude[p];
    }
  }
  // Multiple contrast levels recover dim boundaries as well as bright pages.
  final threshold = (sum / (w*h) * 2.2).clamp(32.0, 100.0);
  DocumentQuad? best;
  var area = 0.0;
  for (final level in [threshold, threshold * .6, threshold * 1.6]) {
    final edges = Uint8List(w*h);
    for (var i = 0; i < edges.length; i++) {
      if (magnitude[i] > level) edges[i] = 1;
    }
    final candidate = _fromEdges(edges, w, h);
    if (candidate != null && candidate.area > area) {
      best = candidate;
      area = candidate.area;
    }
  }
  return best;
}

DocumentQuad? _fromEdges(Uint8List edges, int w, int h) {
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
    final contour = <math.Point<double>>[];
    for (var head = 0; head < queue.length; head++) {
      final pos = queue[head], x = pos % w, y = pos ~/ w;
      if (edges[pos] != 0) contour.add(math.Point(x.toDouble(), y.toDouble()));
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
    final points = _quadrilateral(contour);
    if (points == null) continue;
    var area = 0.0;
    var valid = true;
    for (var i = 0; i < 4; i++) {
      final a = points[i], b = points[(i + 1) % 4], c = points[(i + 2) % 4];
      area += a.x * b.y - b.x * a.y;
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross <= 0 ||
          a.distanceTo(b) < math.min(w, h) * 0.18 ||
          a.x < 3 ||
          a.y < 3 ||
          a.x > w - 4 ||
          a.y > h - 4)
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
      if (supported < 21) valid = false;
    }
    area = area.abs() / 2;
    if (!valid ||
        area < w * h * 0.12 ||
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

// Monotone-chain hull, reduced by the smallest corner area. Keeps perspective
// and rotated pages; each resulting side is independently checked against edges.
List<math.Point<double>>? _quadrilateral(List<math.Point<double>> points) {
  if (points.length < 4) return null;
  points.sort((a,b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
  double cross(math.Point<double> a, math.Point<double> b, math.Point<double> c) =>
    (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
  final lower = <math.Point<double>>[], upper = <math.Point<double>>[];
  for (final p in points) {
    while (lower.length >= 2 && cross(lower[lower.length-2],lower.last,p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  for (final p in points.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length-2],upper.last,p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  final hull = [...lower.take(lower.length-1), ...upper.take(upper.length-1)];
  while (hull.length > 4) {
    var smallest = double.infinity, index = 0;
    for (var i=0; i<hull.length; i++) {
      final value = cross(hull[(i+hull.length-1)%hull.length], hull[i],
        hull[(i+1)%hull.length]).abs();
      if (value < smallest) { smallest=value; index=i; }
    }
    hull.removeAt(index);
  }
  if (hull.length != 4) return null;
  var first = 0;
  for (var i=1; i<4; i++) {
    if (hull[i].x+hull[i].y < hull[first].x+hull[first].y) first=i;
  }
  return List.generate(4,(i) => hull[(first+i)%4]);
}

/// Variance of a luminance Laplacian. A quality gate, not an invented contour.
double frameSharpness(Uint8List gray, int width, int height) {
  var sum = 0.0, squared = 0.0, count = 0;
  for (var y=2; y<height-2; y+=2) {
    for (var x=2; x<width-2; x+=2) {
      final p=y*width+x;
      final value=4*gray[p]-gray[p-1]-gray[p+1]-gray[p-width]-gray[p+width];
      sum+=value; squared+=value*value; count++;
    }
  }
  return count == 0 ? 0 : squared/count - math.pow(sum/count,2).toDouble();
}

class AutoCaptureGate {
  DocumentQuad? anchor;
  DateTime? stableSince;
  bool awaitingRemoval = false;
  int missingFrames = 0;
  void reset({bool clearRemoval = false}) {
    if (clearRemoval) awaitingRemoval = false;
    anchor = null;
    stableSince = null;
    missingFrames = 0;
  }

  void captured() {
    reset();
    awaitingRemoval = true;
  }

  bool update(DocumentQuad? quad, DateTime now, {bool ready = true}) {
    if (quad == null) {
      anchor = null;
      stableSince = null;
      if (++missingFrames >= 3) awaitingRemoval = false;
      return false;
    }
    missingFrames = 0;
    if (awaitingRemoval) return false;
    if (!ready) { anchor = null; stableSince = null; return false; }
    if (anchor == null || anchor!.distance(quad) > 0.025) {
      anchor = quad;
      stableSince = now;
      return false;
    }
    return now.difference(stableSince!).inMilliseconds >= 1200;
  }
}
