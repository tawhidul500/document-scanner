import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';

void main() {
  late Directory dir;
  late DocumentStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('home_test_');
    store = DocumentStore(dir);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await dir.delete(recursive: true);
  });

  testWidgets('home has live counts and searchable saved files', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 813);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final doc = await store.addBytes(
        utf8.encode('test QR'),
        ScanKind.qr,
        'txt',
      );
      await store.rename(doc, 'My QR');
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Scan Options'), findsOneWidget);
    expect(find.text('My QR.txt'), findsOneWidget);
    expect(find.text('1 file'), findsOneWidget);
    await tester.tap(find.byTooltip('Search files'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not present');
    await tester.pumpAndSettle();
    expect(find.text('No matching files'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'MY QR');
    await tester.pumpAndSettle();
    expect(find.text('My QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty home fits a small phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('0 files'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
