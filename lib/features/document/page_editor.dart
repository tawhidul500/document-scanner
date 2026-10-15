import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'page_processing.dart';

class PageEditor extends StatefulWidget {
  const PageEditor({super.key, required this.path, this.sign = false});
  final String path;
  final bool sign;
  @override
  State<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<PageEditor> {
  Uint8List? bytes;
  double aspect = 0.75;
  bool busy = false;
  String? error;
  final corners = <Offset>[
    const Offset(0, 0),
    const Offset(1, 0),
    const Offset(1, 1),
    const Offset(0, 1),
  ];
  final strokes = <List<Offset>>[];
  int? dragging;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await File(widget.path).readAsBytes();
      final decoded = await compute(_dimensions, data);
      if (mounted)
        setState(() {
          bytes = data;
          aspect = decoded;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open this page.');
    }
  }

  static double _dimensions(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) throw const FormatException('Invalid image');
    return image.width / image.height;
  }

  Future<void> apply() async {
    if (bytes == null || busy) return;
    if (!widget.sign) {
      for (var i = 0; i < 4; i++) {
        final a = corners[i],
            b = corners[(i + 1) % 4],
            c = corners[(i + 2) % 4];
        if ((b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx) <=
                0 ||
            (b - a).distance < 0.05) {
          setState(() => error = 'Keep four corners in clockwise order.');
          return;
        }
      }
    }
    setState(() => busy = true);
    try {
      final result = await compute(processPage, <String, Object>{
        'bytes': bytes!,
        if (!widget.sign)
          'corners': corners.expand((p) => [p.dx, p.dy]).toList(),
        if (widget.sign)
          'strokes': strokes
              .map((s) => s.expand((p) => [p.dx, p.dy]).toList())
              .toList(),
      });
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not apply changes. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.sign ? 'Sign page' : 'Crop',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.sign)
            IconButton(
              tooltip: 'Undo stroke',
              onPressed: busy || strokes.isEmpty
                  ? null
                  : () => setState(() => strokes.removeLast()),
              icon: const Icon(Icons.undo),
            ),
          TextButton(
            onPressed: busy || bytes == null ? null : apply,
            child: const Text(
              'Done',
              style: TextStyle(color: Color(0xFF5262FF), fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (error != null || widget.sign)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error ??
                    (widget.sign
                        ? 'Draw your signature directly where you want it on the page.'
                        : 'Drag each corner to the document edge.'),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 35, 28, 16),
              child: bytes == null
                  ? const Center(child: CircularProgressIndicator())
                  : Align(
                      alignment: Alignment.topCenter,
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            Offset normalized(Offset p) => Offset(
                              (p.dx / box.maxWidth).clamp(0.0, 1.0).toDouble(),
                              (p.dy / box.maxHeight).clamp(0.0, 1.0).toDouble(),
                            );
                            return GestureDetector(
                              onPanStart: busy
                                  ? null
                                  : (event) => setState(() {
                                      final point = normalized(
                                        event.localPosition,
                                      );
                                      if (widget.sign) {
                                        strokes.add([point]);
                                      } else {
                                        var nearest = double.infinity;
                                        for (var i = 0; i < 4; i++) {
                                          final distance =
                                              (point - corners[i]).distance;
                                          if (distance < nearest) {
                                            nearest = distance;
                                            dragging = i;
                                          }
                                        }
                                      }
                                    }),
                              onPanUpdate: busy
                                  ? null
                                  : (event) => setState(() {
                                      final point = normalized(
                                        event.localPosition,
                                      );
                                      if (widget.sign) {
                                        if (strokes.isNotEmpty)
                                          strokes.last.add(point);
                                      } else if (dragging != null) {
                                        corners[dragging!] = point;
                                      }
                                    }),
                              onPanEnd: (_) => dragging = null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(bytes!, fit: BoxFit.fill),
                                  CustomPaint(
                                    painter: _EditorPainter(
                                      widget.sign ? null : corners,
                                      strokes,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

class _EditorPainter extends CustomPainter {
  _EditorPainter(this.corners, this.strokes);
  final List<Offset>? corners;
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    Offset scale(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    if (corners != null) {
      final path = Path()..addPolygon(corners!.map(scale).toList(), true);
      canvas.drawPath(path, Paint()..color = const Color(0x555262FF));
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.square
        ..color = const Color(0xFF5262FF);
      for (var i = 0; i < corners!.length; i++) {
        final point = scale(corners![i]);
        for (final neighbor in [(i + 3) % 4, (i + 1) % 4]) {
          final delta = scale(corners![neighbor]) - point;
          if (delta.distance > 0) {
            canvas.drawLine(point, point + delta / delta.distance * 23, edge);
          }
        }
      }
    }
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(scale(stroke.first).dx, scale(stroke.first).dy);
      for (final p in stroke.skip(1)) path.lineTo(scale(p).dx, scale(p).dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF10244A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_EditorPainter oldDelegate) => true;
}
