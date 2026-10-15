import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Color matrix shared by live previews, thumbnails and exported pixels.
List<double> documentFilterMatrix(int preset, double strength) {
  final target = switch (preset) {
    1 => <double>[
      .90,
      0,
      0,
      0,
      5,
      0,
      1.02,
      0,
      0,
      10,
      0,
      0,
      1.12,
      0,
      16,
      0,
      0,
      0,
      1,
      0,
    ],
    2 => <double>[
      1.12,
      0,
      0,
      0,
      16,
      0,
      .92,
      0,
      0,
      4,
      0,
      0,
      1.02,
      0,
      10,
      0,
      0,
      0,
      1,
      0,
    ],
    3 => <double>[
      .90,
      .08,
      .02,
      0,
      18,
      .04,
      .88,
      .03,
      0,
      16,
      .02,
      .08,
      .80,
      0,
      8,
      0,
      0,
      0,
      1,
      0,
    ],
    4 => <double>[
      .82,
      .10,
      .03,
      0,
      18,
      .06,
      .82,
      .06,
      0,
      18,
      .06,
      .10,
      .78,
      0,
      18,
      0,
      0,
      0,
      1,
      0,
    ],
    _ => <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  };
  final identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  return List.generate(
    20,
    (i) => identity[i] + (target[i] - identity[i]) * strength,
  );
}

/// Physical dimensions in PDF points; original uses the review raster's 144 dpi.
List<double> documentPaperSize(String key, int width, int height) =>
    switch (key) {
      'a4' => [595.276, 841.890],
      'a5' => [419.528, 595.276],
      'id' => [242.646, 153.014],
      'legal' => [612, 1008],
      _ => [width / 2, height / 2],
    };

Uint8List applyEditorTool(Map<String, Object> request) {
  final bytes = request['bytes'] as Uint8List;
  final source = img.decodeImage(bytes);
  if (source == null) throw const FormatException('Invalid image');
  final operation = request['tool'] as String;
  var output = img.bakeOrientation(source);
  if (operation == 'filter') {
    final preset = request['preset'] as int;
    if (preset == 0) return bytes;
    final m = documentFilterMatrix(preset, request['strength'] as double);
    for (final p in output) {
      final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
      p.r = (m[0] * r + m[1] * g + m[2] * b + m[4]).clamp(0, 255).round();
      p.g = (m[5] * r + m[6] * g + m[7] * b + m[9]).clamp(0, 255).round();
      p.b = (m[10] * r + m[11] * g + m[12] * b + m[14]).clamp(0, 255).round();
    }
  } else if (operation == 'rotate') {
    final turns = request['turns'] as int;
    if (turns % 4 == 0) return bytes;
    output = img.copyRotate(output, angle: turns * 90);
  }
  // PNG avoids repeated JPEG loss while moving among editing tools.
  return Uint8List.fromList(img.encodePng(output));
}
