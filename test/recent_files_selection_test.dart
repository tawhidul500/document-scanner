import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_folders.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';
import 'support/pump_until.dart';

Future<DocumentStore> mountRecent(WidgetTester tester, {VoidCallback? onOpen}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final directory = Directory.systemTemp.createTempSync('recent_selection_');
  final store = DocumentStore(directory);
  await tester.runAsync(() async {
    await store.addBytes([65], ScanKind.document, 'txt', name: 'Doc First');
    await store.addBytes([66], ScanKind.document, 'txt', name: 'Doc Second');
    await store.addBytes([67], ScanKind.qr, 'txt', name: 'QR Third');
    final folders = DocumentFolders(store);
    await folders.create('Archive');
    await folders.move([store.files.last.id], folders.names.keys.single);
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    directory.deleteSync(recursive: true);
  });
  await tester.pumpWidget(MaterialApp(
    home: RecentFilesScreen(
      store: store,
      onOpen: (_) async { onOpen?.call(); },
      onAction: (_, __) async {},
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

TextButton action(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.byKey(ValueKey('recent-action-' + label)));

void main() {
  testWidgets('long press and row taps select without opening files', (tester) async {
    var opened = 0;
    await mountRecent(tester, onOpen: () => opened++);
    await tester.longPress(find.text('Doc First'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    await tester.tap(find.text('Doc Second'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
    expect(opened, 0);
    expect(action(tester, 'move').onPressed, isNotNull);
    expect(action(tester, 'merge').onPressed, isNotNull);
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Doc First'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('file menu includes Select and enters selection mode', (tester) async {
    await mountRecent(tester);
    await tester.tap(find.byTooltip('File options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
  });

  testWidgets('header Select all, Deselect all and mixed-category actions', (tester) async {
    await mountRecent(tester);
    await tester.tap(find.byTooltip('Select files'));
    await tester.pumpAndSettle();
    expect(find.text('Select items'), findsOneWidget);
    for (final label in ['move', 'share', 'merge', 'delete']) {
      expect(action(tester, label).onPressed, isNull);
    }
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 Selected'), findsOneWidget);
    expect(action(tester, 'move').onPressed, isNull);
    for (final label in ['share', 'merge', 'delete']) {
      expect(action(tester, label).onPressed, isNotNull);
    }
    await tester.tap(find.text('Deselect all'));
    await tester.pumpAndSettle();
    expect(find.text('Select items'), findsOneWidget);
    expect(action(tester, 'delete').onPressed, isNull);
  });

  testWidgets('filters clear hidden selection and Select all stays scoped', (tester) async {
    await mountRecent(tester);
    await tester.longPress(find.text('Doc First'));
    await tester.tap(find.byKey(const ValueKey('recent-filter-qr')));
    await tester.pumpAndSettle();
    expect(find.text('Select items'), findsOneWidget);
    expect(find.byType(FileRow), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Recent Files'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('search changes clear selected files that are no longer visible', (tester) async {
    await mountRecent(tester);
    await tester.tap(find.byTooltip('Search recent files'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Doc');
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Doc First'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'QR');
    await tester.pumpAndSettle();
    expect(find.text('Select items'), findsOneWidget);
    expect(find.byType(FileRow), findsOneWidget);
    expect(action(tester, 'delete').onPressed, isNull);
  });

  testWidgets('external deletion removes stale selected IDs', (tester) async {
    final store = await mountRecent(tester);
    final first = store.files.singleWhere((file) => file.name == 'Doc First');
    await tester.longPress(find.text('Doc First'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => store.delete(first));
    await tester.pumpAndSettle();
    expect(find.text('Select items'), findsOneWidget);
    expect(action(tester, 'delete').onPressed, isNull);
  });

  testWidgets('bulk delete asks first and cleans category folder membership', (tester) async {
    final store = await mountRecent(tester);
    await tester.tap(find.byTooltip('Select files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.files, hasLength(3));
    await tester.tap(find.byKey(const ValueKey('recent-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ok'));
    await pumpUntil(tester,
        () => store.files.isEmpty && find.text('Recent Files').evaluate().isNotEmpty,
        reason: 'bulk deletion and folder cleanup to finish');
    await tester.pumpAndSettle();
    expect(store.files, isEmpty);
    final folders = DocumentFolders(store);
    await tester.runAsync(folders.load);
    expect(folders.membership, isEmpty);
    expect(folders.names.values, contains('Archive'));
    expect(find.text('Recent Files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Move uses the category folder index for all selected files', (tester) async {
    final store = await mountRecent(tester);
    await tester.tap(find.byKey(const ValueKey('recent-filter-document')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-action-move')));
    await pumpUntil(tester, () => find.text('Archive').evaluate().isNotEmpty,
        reason: 'the destination folder list to load');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await pumpUntil(tester, () => find.text('Recent Files').evaluate().isNotEmpty,
        reason: 'the selected files to move');
    await tester.pumpAndSettle();
    final folders = DocumentFolders(store);
    await tester.runAsync(folders.load);
    final id = folders.names.keys.single;
    for (final file in store.files.where((file) => file.kind == ScanKind.document)) {
      expect(folders.membership[file.id], id);
    }
    expect(find.text('Recent Files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Merge saves a new PDF while retaining originals', (tester) async {
    final store = await mountRecent(tester);
    await tester.tap(find.byKey(const ValueKey('recent-filter-document')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-action-merge')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Merged Recent');
    await tester.tap(find.text('Ok'));
    await pumpUntil(tester,
        () => store.files.any((file) => file.name == 'Merged Recent') &&
            find.text('Recent Files').evaluate().isNotEmpty,
        reason: 'the merged PDF to be saved');
    await tester.pumpAndSettle();
    expect(store.files, hasLength(4));
    final merged = store.files.singleWhere((file) => file.name == 'Merged Recent');
    expect(merged.extension, 'pdf');
    expect(merged.kind, ScanKind.document);
    expect(store.files.any((file) => file.name == 'Doc First'), isTrue);
    expect(store.files.any((file) => file.name == 'Doc Second'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
