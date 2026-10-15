import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/data/document_folders.dart';
import 'package:pdf_scanner/features/folders/document_folder_screen.dart';

void main() {
  for (final kind in ScanKind.values) {
    testWidgets('${kind.label} uses shared select/all/none behavior', (
      tester,
    ) async {
      final directory = await Directory.systemTemp.createTemp('category_test_');
      final store = DocumentStore(directory);
      try {
        await store.addBytes([65], kind, 'txt', name: 'First');
        await store.addBytes([66], kind, 'txt', name: 'Second');
        final other = ScanKind.values.firstWhere((k) => k != kind);
        await store.addBytes([67], other, 'txt', name: 'Other category');
        await tester.pumpWidget(
          MaterialApp(
            home: DocumentFolderScreen(
              store: store,
              kind: kind,
              onOpen: (_) async {},
              onAction: (_, __) async {},
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(find.text(kind.label), findsOneWidget);
        expect(find.text('Other category'), findsNothing);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Move'))
              .onPressed,
          isNull,
        );
        await tester.longPress(find.text('First'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        expect(find.text('2 Selected'), findsOneWidget);
        await tester.tap(find.text('Deselect all'));
        await tester.pumpAndSettle();
        expect(find.text('Select items'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        store.dispose();
        await directory.delete(recursive: true);
      }
    });
  }

  test('category folder metadata is isolated and survives reload', () async {
    final directory = await Directory.systemTemp.createTemp('category_store_');
    final store = DocumentStore(directory);
    try {
      for (final kind in ScanKind.values) {
        final scan = await store.addBytes([65], kind, 'txt');
        final folders = DocumentFolders(store, kind: kind);
        await folders.create('${kind.label} folder');
        await folders.move([scan.id], folders.names.keys.single);
      }
      for (final kind in ScanKind.values) {
        final folders = DocumentFolders(store, kind: kind);
        await folders.load();
        expect(folders.names.values.single, '${kind.label} folder');
        final member = store.files.singleWhere(
          (f) => f.id == folders.membership.keys.single,
        );
        expect(member.kind, kind);
        final other = store.files.firstWhere((f) => f.kind != kind);
        await expectLater(
          folders.move([other.id], folders.names.keys.single),
          throwsStateError,
        );
      }
      await store.load();
      expect(store.unreadableRecords, 0);
      expect(store.files.length, 4);
    } finally {
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
