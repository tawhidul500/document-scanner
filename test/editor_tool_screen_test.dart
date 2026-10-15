import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/editor_tools.dart';

void main() {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 60, height: 100)),
  );
  Widget screen(EditorTool tool) => MaterialApp(
    home: EditorToolScreen(
      tool: tool,
      bytes: bytes,
      name: 'Document',
      paperSize: 'a4',
    ),
  );

  testWidgets('Filter displays presets and live strength control', (
    tester,
  ) async {
    await tester.pumpWidget(screen(EditorTool.filter));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('No Filter'), findsOneWidget);
    await tester.tap(find.text('AddictiveRed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Resize displays paper presets in the bottom toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(screen(EditorTool.resize));
    await tester.pumpAndSettle();
    for (final name in paperNames) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('ID Card'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Rotate Left followed by Right restores preview orientation', (
    tester,
  ) async {
    await tester.pumpWidget(screen(EditorTool.rotate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate Left'));
    await tester.pump();
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 3);
    await tester.tap(find.text('Rotate Right'));
    await tester.pump();
    expect(find.byType(RotatedBox), findsNothing);
  });
}
