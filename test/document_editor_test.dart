import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/editor_processing.dart';

void main() {
  final source = img.Image(width: 60, height: 100);
  img.fill(source, color: img.ColorRgb8(210, 80, 30));
  final bytes = Uint8List.fromList(img.encodePng(source));

  test('left and right rotations restore original pixels', () {
    final left = applyEditorTool({
      'bytes': bytes,
      'tool': 'rotate',
      'turns': 3,
    });
    final rotated = img.decodeImage(left)!;
    expect(rotated.width, 100);
    expect(rotated.height, 60);
    final restored = img.decodeImage(
      applyEditorTool({'bytes': left, 'tool': 'rotate', 'turns': 1}),
    )!;
    expect(restored.width, source.width);
    expect(restored.height, source.height);
    expect(restored.getPixel(20, 20).r, 210);
  });
  test('zero filter strength preserves source colors', () {
    final output = img.decodeImage(
      applyEditorTool({
        'bytes': bytes,
        'tool': 'filter',
        'preset': 2,
        'strength': 0.0,
      }),
    )!;
    final pixel = output.getPixel(20, 20);
    expect([pixel.r, pixel.g, pixel.b], [210, 80, 30]);
  });
  test('No Filter returns unchanged bytes', () {
    expect(
      identical(
        applyEditorTool({
          'bytes': bytes,
          'tool': 'filter',
          'preset': 0,
          'strength': 1.0,
        }),
        bytes,
      ),
      isTrue,
    );
  });
  test('filter export uses the same matrix as its preview', () {
    final matrix = documentFilterMatrix(1, .4);
    final pixel = img
        .decodeImage(
          applyEditorTool({
            'bytes': bytes,
            'tool': 'filter',
            'preset': 1,
            'strength': .4,
          }),
        )!
        .getPixel(20, 20);
    expect(pixel.r, (matrix[0] * 210 + matrix[4]).round());
    expect(pixel.b, (matrix[12] * 30 + matrix[14]).round());
  });
  test('paper choices use physical dimensions', () {
    expect(documentPaperSize('a4', 60, 100), [595.276, 841.890]);
    expect(documentPaperSize('legal', 60, 100), [612, 1008]);
    final id = documentPaperSize('id', 60, 100);
    expect(id[0], greaterThan(id[1]));
  });
  test('invalid image fails before exporting', () {
    expect(
      () => applyEditorTool({
        'bytes': Uint8List(0),
        'tool': 'rotate',
        'turns': 1,
      }),
      throwsFormatException,
    );
  });
}
