import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'edge_detector.dart';
import 'scan_enhancement.dart';
import 'perspective.dart';
import 'editor_processing.dart';

Uint8List processPage(Map<String, Object> request) {
  final decoded = img.decodeImage(request['bytes'] as Uint8List);
  if (decoded == null)
    throw const FormatException('Could not decode this image.');
  var source = img.bakeOrientation(decoded);
  if (math.max(source.width, source.height) > 2400) {
    source = img.copyResize(
      source,
      width: source.width >= source.height ? 2400 : null,
      height: source.height > source.width ? 2400 : null,
    );
  }
  if (request['rotate'] == true) source = img.copyRotate(source, angle: 90);
  DocumentQuad? quad;
  final supplied = request['corners'] as List<double>?;
  if (supplied != null) {
    quad = DocumentQuad(
      List.generate(4, (i) => math.Point(supplied[i * 2], supplied[i * 2 + 1])),
    );
  } else if (request['detect'] == true) {
    final tiny = img.copyResize(source, width: 480);
    final gray = Uint8List(tiny.width * tiny.height);
    for (var y = 0; y < tiny.height; y++) {
      for (var x = 0; x < tiny.width; x++) {
        final p = tiny.getPixel(x, y);
        gray[y * tiny.width + x] = ((p.r * 299 + p.g * 587 + p.b * 114) / 1000)
            .round();
      }
    }
    quad = detectDocument({
      'gray': gray,
      'width': tiny.width,
      'height': tiny.height,
    });
  }
  if (quad != null) {
    final q = quad.points
        .map(
          (p) => img.Point(p.x * (source.width - 1), p.y * (source.height - 1)),
        )
        .toList();
    double length(int a, int b) =>
        math.sqrt(math.pow(q[a].x - q[b].x, 2) + math.pow(q[a].y - q[b].y, 2));
    final width = math
        .max(length(0, 1), length(3, 2))
        .round()
        .clamp(2, 2400)
        .toInt();
    final height = math
        .max(length(0, 3), length(1, 2))
        .round()
        .clamp(2, 2400)
        .toInt();
    source = rectifyDocument(source, quad, width, height);
  }
  if (request['enhance'] == true) source = enhanceScan(source);
  final strokes = request['strokes'] as List<List<double>>?;
  if (strokes != null) {
    for (final stroke in strokes) {
      for (var i = 2; i < stroke.length; i += 2) {
        img.drawLine(
          source,
          x1: (stroke[i - 2] * (source.width - 1)).round(),
          y1: (stroke[i - 1] * (source.height - 1)).round(),
          x2: (stroke[i] * (source.width - 1)).round(),
          y2: (stroke[i + 1] * (source.height - 1)).round(),
          color: img.ColorRgb8(16, 36, 74),
          thickness: math.max(2, (source.width / 150).round()),
        );
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(source, quality: 92));
}

Future<Uint8List> buildDocumentPdf(
  List<Uint8List> pages, {
  List<String>? paperSizes,
}) async {
  final pdf = pw.Document();
  for (var index = 0; index < pages.length; index++) {
    final bytes = pages[index];
    var format = PdfPageFormat.a4;
    if (paperSizes != null) {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw const FormatException('Invalid page image');
      final dimensions = documentPaperSize(
        paperSizes[index],
        decoded.width,
        decoded.height,
      );
      format = PdfPageFormat(dimensions[0], dimensions[1]);
    }
    final image = pw.MemoryImage(bytes);
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return pdf.save();
}
