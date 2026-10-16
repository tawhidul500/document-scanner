import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';
import 'package:pdf_scanner/widgets/reference_navigation.dart';

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
  testWidgets('reference empty state retains working camera and settings', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 813);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('No files here yet'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    expect(find.text('0 files'), findsNWidgets(4));
    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Import PDF'), findsOneWidget);
    expect(tester.widget<ReferenceHomeNavigation>(
      find.byType(ReferenceHomeNavigation)).cameraVisible, isFalse);
    expect(find.byTooltip('Scan'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.widget<ReferenceHomeNavigation>(
      find.byType(ReferenceHomeNavigation)).cameraVisible, isFalse);
    await tester.pumpAndSettle();
    expect(tester.widget<ReferenceHomeNavigation>(
      find.byType(ReferenceHomeNavigation)).cameraVisible, isTrue);
    expect(find.byTooltip('Scan'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
