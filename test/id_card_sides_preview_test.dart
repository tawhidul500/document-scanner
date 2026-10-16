import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/id_card_preview.dart';

void main() {
  testWidgets('ID preview has front/back card surfaces rather than document pages', (tester) async {
    final bytes=Uint8List.fromList(img.encodePng(img.Image(width:856,height:540)));
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:IdCardSidesPreview(sides:[bytes,bytes]))));
    await tester.pumpAndSettle();
    expect(find.text('Front side'),findsOneWidget);
    expect(find.text('Back side'),findsOneWidget);
    expect(find.byType(PageView),findsNothing);
    expect(find.byType(AspectRatio),findsNWidgets(2));
    for (final card in tester.widgetList<AspectRatio>(find.byType(AspectRatio))) {
      expect(card.aspectRatio,closeTo(85.6/54,.001));
    }
    expect(tester.takeException(),isNull);
  });
}
