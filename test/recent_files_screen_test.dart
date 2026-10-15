import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';

void main() {
  testWidgets('Recent filters, search, opening and live deletion', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('recent_test_');
    final store = DocumentStore(directory);
    String? opened;
    try {
      for (final kind in ScanKind.values) {
        await store.addBytes([65], kind, 'txt', name: 'Sample_${kind.name}');
      }
      await tester.pumpWidget(
        MaterialApp(
          home: RecentFilesScreen(
            store: store,
            onOpen: (file) async {
              opened = file.id;
            },
            onAction: (_, __) async {},
          ),
        ),
      );
      expect(find.byType(FileRow), findsNWidgets(4));
      final rows = tester.widgetList<FileRow>(find.byType(FileRow)).toList();
      expect(rows.first.document.kind, ScanKind.barcode);
      for (final kind in ScanKind.values) {
        await tester.tap(find.byKey(ValueKey('recent-filter-${kind.name}')));
        await tester.pumpAndSettle();
        expect(find.byType(FileRow), findsOneWidget);
        expect(
          tester.widget<FileRow>(find.byType(FileRow)).document.kind,
          kind,
        );
      }
      await tester.tap(find.text('Sample_barcode'));
      await tester.pumpAndSettle();
      expect(opened, store.files.first.id);
      await tester.tap(find.byKey(const ValueKey('recent-filter-all')));
      await tester.tap(find.byTooltip('Search recent files'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sample_qr');
      await tester.pumpAndSettle();
      expect(find.byType(FileRow), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching files'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => store.delete(store.files.first));
      await tester.pumpAndSettle();
      expect(find.byType(FileRow), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
