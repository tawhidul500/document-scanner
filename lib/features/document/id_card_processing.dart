import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'page_processing.dart';
import 'edge_detector.dart';

/// Matches the guide shown over the cover-fitted portrait camera preview.
List<double> idCardGuide(double width, double height) {
  final guideWidth = math.min(width - 36, height * .62 * (85.6 / 54));
  final guideHeight = guideWidth / (85.6 / 54);
  return [
    (width - guideWidth) / 2,
    height * .50 - guideHeight / 2,
    guideWidth,
    guideHeight,
  ];
}

Uint8List processIdCardCapture(Map<String, Object> request) {
  final image = img.decodeImage(request['bytes'] as Uint8List);
  if (image == null) throw const FormatException('Invalid capture');
  final source = img.bakeOrientation(image);
  // Re-detect against the still photo: preview and still streams may have
  // different fields of view. Never reuse preview coordinates for the crop.
  if (request['detectCard'] == true) {
    final tiny=img.copyResize(source,width:480);
    final gray=Uint8List(tiny.width*tiny.height);
    for (var y=0;y<tiny.height;y++) {
      for (var x=0;x<tiny.width;x++) {
        final p=tiny.getPixel(x,y);
        gray[y*tiny.width+x]=((p.r*299+p.g*587+p.b*114)/1000).round();
      }
    }
    final quad=detectDocument({'gray':gray,'width':tiny.width,'height':tiny.height});
    if (quad != null) {
      final points=quad.points.map((p) => math.Point(p.x*tiny.width,p.y*tiny.height)).toList();
      final width=(points[0].distanceTo(points[1])+points[3].distanceTo(points[2]))/2;
      final height=(points[0].distanceTo(points[3])+points[1].distanceTo(points[2]))/2;
      final ratio=math.max(width,height)/math.max(1,math.min(width,height));
      if (ratio>=1.2 && ratio<=2.1) {
        return processPage({
          'bytes': request['bytes'] as Uint8List,
          'corners': quad.points.expand((p) => [p.x,p.y]).toList(),
          'enhance': request['enhance'] == true,
        });
      }
    }
  }

  final viewWidth = request['width'] as double,
      viewHeight = request['height'] as double;
  final guide = idCardGuide(viewWidth, viewHeight);
  final zoom = math.max(viewWidth / source.width, viewHeight / source.height);
  final offsetX = (viewWidth - source.width * zoom) / 2;
  final offsetY = (viewHeight - source.height * zoom) / 2;
  final x = ((guide[0] - offsetX) / zoom)
      .round()
      .clamp(0, source.width - 1)
      .toInt();
  final y = ((guide[1] - offsetY) / zoom)
      .round()
      .clamp(0, source.height - 1)
      .toInt();
  final width = (guide[2] / zoom).round().clamp(1, source.width - x).toInt();
  final height = (guide[3] / zoom).round().clamp(1, source.height - y).toInt();
  final cropped = img.copyCrop(
    source,
    x: x,
    y: y,
    width: width,
    height: height,
  );
  return processPage({
    'bytes': Uint8List.fromList(img.encodePng(cropped)),
    'detect': true,
    'enhance': request['enhance'] == true,
  });
}

/// ID previews always use landscape card orientation without stretching pixels.
Uint8List orientIdCard(Uint8List bytes) {
  final image=img.decodeImage(bytes);
  if (image == null) throw const FormatException('Invalid ID card image');
  if (image.height <= image.width) return bytes;
  return Uint8List.fromList(img.encodeJpg(img.copyRotate(image,angle:90),quality:94));
}

Future<Uint8List> buildIdCardPdf(List<String> paths) async {
  if (paths.isEmpty || paths.length > 2)
    throw const FormatException('Capture one or two card sides.');
  final images = <pw.MemoryImage>[];
  for (final path in paths) {
    images.add(pw.MemoryImage(await File(path).readAsBytes()));
  }
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(44),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 40),
          for (var i = 0; i < images.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 34),
            pw.SizedBox(
              width: 85.6 * PdfPageFormat.mm,
              height: 54 * PdfPageFormat.mm,
              child: pw.Image(images[i], fit: pw.BoxFit.contain),
            ),
          ],
        ],
      ),
    ),
  );
  return pdf.save();
}
