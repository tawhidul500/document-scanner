import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/widgets/scanner_camera_shell.dart';

void main() {
  testWidgets('mode strip scrolls both ways and changes selected scan kind', (tester) async {
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.reset);
    var kind=ScanKind.document;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context,setState) =>
      ScannerCameraShell(kind:kind,status:'Looking for document',
        preview:const ColoredBox(color:Colors.black),
        onMode:(value) => setState(() => kind=value)))));
    await tester.drag(find.byType(PageView),const Offset(-100,0));
    await tester.pumpAndSettle();
    expect(kind,ScanKind.idCard);
    await tester.drag(find.byType(PageView),const Offset(100,0));
    await tester.pumpAndSettle();
    expect(kind,ScanKind.document);
    expect(tester.takeException(),isNull);
  });

  testWidgets('small viewports keep shutter and imports usable', (tester) async {
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(320,568);
    addTearDown(tester.view.reset);
    var capture=0, images=0, files=0;
    await tester.pumpWidget(MaterialApp(home: ScannerCameraShell(
      kind:ScanKind.document,status:'Document detected',detected:true,
      preview:const ColoredBox(color:Colors.black),
      onCapture:() => capture++,onImages:() => images++,onFiles:() => files++)));
    await tester.tap(find.bySemanticsLabel('Capture document'));
    await tester.tap(find.text('Import Images'));
    await tester.tap(find.text('Import Files'));
    expect([capture,images,files],[1,1,1]);
    expect(tester.takeException(),isNull);
  });
  testWidgets('ID Card opens selected above shutter with shared controls', (tester) async {
    tester.view.devicePixelRatio=1;
    tester.view.physicalSize=const Size(390,844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ScannerCameraShell(
      kind:ScanKind.idCard,status:'Align the ID card',
      preview:const ColoredBox(color:Colors.black),
      onMode:(_) {},onAuto:() {},onEnhance:() {},onCapture:() {})));
    await tester.pumpAndSettle();
    final tab=find.byKey(const ValueKey('scanner-mode-idCard'));
    final shutter=find.bySemanticsLabel('Capture document');
    expect(tester.getCenter(tab).dx,closeTo(tester.getCenter(shutter).dx,1));
    expect(tester.getCenter(tab).dy,lessThan(tester.getCenter(shutter).dy));
    expect(find.text('One side'),findsOneWidget);
    expect(find.text('Both side'),findsOneWidget);
    expect(find.text('Single'),findsNothing);
    expect(find.text('Batch'),findsNothing);
    expect(find.text('Auto'),findsOneWidget);
    expect(find.byTooltip('Auto enhance on'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

}
