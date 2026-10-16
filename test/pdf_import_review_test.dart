import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/data/document_folders.dart';
import 'package:pdf_scanner/features/document/document_editor.dart';
import 'package:pdf_scanner/features/document/document_review.dart';
import 'package:pdf_scanner/features/folders/document_folder_screen.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pickerChannel = MethodChannel('flutter_file_dialog');
  const pathsChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late Directory cache;
  late DocumentStore store;
  late File source;
  late Uint8List sourceBytes;
  late PrintingPlatform originalPrinting;
  late _TestPrinting printing;
  String? pickedPath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pdf_import_test_');
    cache = await Directory('${directory.path}/cache').create();
    store = DocumentStore(Directory('${directory.path}/documents'));
    await store.load();
    final pdf = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.SizedBox()))
      ..addPage(pw.Page(build: (_) => pw.SizedBox()));
    sourceBytes = await pdf.save();
    source = await File('${directory.path}/Imported.pdf')
        .writeAsBytes(sourceBytes);
    pickedPath = source.path;
    originalPrinting = PrintingPlatform.instance;
    printing = _TestPrinting();
    PrintingPlatform.instance = printing;
    messenger.setMockMethodCallHandler(pickerChannel, (call) async {
      if (call.method == 'pickFile') return pickedPath;
      throw StateError('Unexpected file dialog call: ${call.method}');
    });
    messenger.setMockMethodCallHandler(pathsChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') return cache.path;
      throw StateError('Unexpected directory call: ${call.method}');
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(pathsChannel, null);
    PrintingPlatform.instance = originalPrinting;
    store.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
    }
    fail('Expected screen did not appear: $finder');
  }

  Future<void> importPdf(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
  }

  testWidgets('camera PDF import opens all document tools and can be reopened',
      (tester) async {
    await mount(tester);
    // Complete the menu transition before waiting for real file I/O.
    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import PDF'));
    await waitFor(tester, find.byType(DocumentReview));
    expect(find.byType(DocumentPreview), findsNothing);
    expect(find.text('1/2'), findsOneWidget);
    for (final label in ['Option', 'Edit', 'Sign', 'OCR', 'Share', 'Export']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(printing.lastDpi, 144);
    expect(store.files.single.kind, ScanKind.document);
    final review = tester.widget<DocumentReview>(find.byType(DocumentReview));
    expect(review.defaultPaperSize, 'original');
    expect(review.pages.length, 2);
    await tester.runAsync(() async {
      expect(await source.readAsBytes(), orderedEquals(sourceBytes));
      expect(await store.fileFor(store.files.single).readAsBytes(),
          orderedEquals(sourceBytes));
    });

    await tester.tap(find.text('Edit'));
    await waitFor(tester, find.byType(DocumentEditor));
    expect(tester.widget<DocumentEditor>(find.byType(DocumentEditor)).paperSize,
        'original');
    await waitFor(tester, find.text('Undo'));
    // Wait for the page image to load before closing the editor.
    for (var attempt = 0;
        attempt < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
        attempt++) {
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: find.byType(DocumentEditor),
        matching: find.byIcon(Icons.arrow_back)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(DocumentReview),
        matching: find.byIcon(Icons.arrow_back)));
    await waitFor(tester, find.text('Imported.pdf'));
    await tester.runAsync(() async {
      expect(await review.directory.exists(), isFalse);
    });
    await tester.tap(find.text('Imported.pdf'));
    await waitFor(tester, find.text('Open document actions'));
    await tester.tap(find.text('Open document actions'));
    await waitFor(tester, find.byType(DocumentReview));
    expect(find.text('Edit'), findsOneWidget);
    expect(store.files, hasLength(1));
    await tester.tap(find.descendant(of: find.byType(DocumentReview),
        matching: find.byIcon(Icons.arrow_back)));
    await waitFor(tester, find.text('Imported.pdf'));
    expect(tester.takeException(), isNull);
  });

  for (final kind in ScanKind.values) {
    testWidgets('${kind.label} opens document actions from its file list',
        (tester) async {
      final textFile = kind == ScanKind.qr || kind == ScanKind.barcode;
      final content = textFile ? utf8.encode('Saved scan content 123456') : sourceBytes;
      late ScanFile original;
      await tester.runAsync(() async {
        original = await store.addBytes(content, kind, textFile ? 'txt' : 'pdf',
            name: 'Saved scan');
        if (kind == ScanKind.barcode) {
          final folders = DocumentFolders(store, kind: kind);
          await folders.create('Archive');
          await folders.move([original.id], folders.names.keys.single);
        }
      });
      await mount(tester);
      String label = original.filename;
      if (kind == ScanKind.qr) {
        await tester.tap(find.text('See all'));
        await tester.pumpAndSettle();
        label = original.name;
      } else if (kind != ScanKind.document) {
        await tester.tap(find.byWidgetPredicate((widget) =>
            widget is CategoryTile && widget.folder && widget.kind == kind));
        if (kind == ScanKind.barcode) {
          await waitFor(tester, find.text('Archive'));
          await tester.tap(find.text('Archive'));
          await tester.pumpAndSettle();
        }
        label = textFile ? original.name : original.filename;
      }
      final fileList = find.byType(kind == ScanKind.qr
          ? RecentFilesScreen
          : kind == ScanKind.document ? HomeScreen : DocumentFolderScreen);
      final fileLabel = find.descendant(of: fileList, matching: find.text(label));
      await waitFor(tester, fileLabel);
      await tester.tap(fileLabel);
      await waitFor(tester, find.text('Open document actions'));
      for (final action in ['Preview', 'Print', 'Share', 'Export']) {
        expect(find.descendant(of: find.byType(BottomSheet),
            matching: find.text(action)), findsOneWidget);
      }
      await tester.tap(find.text('Open document actions'));
      await waitFor(tester, find.byType(DocumentReview));
      final review = tester.widget<DocumentReview>(find.byType(DocumentReview));
      expect(review.document.extension, 'pdf');
      expect(review.document.id == original.id, !textFile);
      expect(store.files.length, textFile ? 2 : 1);
      for (final action in ['Edit', 'Sign', 'OCR', 'Share', 'Export']) {
        expect(find.text(action), findsOneWidget);
      }
      await tester.runAsync(() async {
        expect(await store.fileFor(original).readAsBytes(), orderedEquals(content));
      });
      await tester.tap(find.descendant(of: find.byType(DocumentReview),
          matching: find.byIcon(Icons.arrow_back)));
      await waitFor(tester, fileLabel);
      await tester.runAsync(() async {
        expect(await review.directory.exists(), isFalse);
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Print sends the original PDF without opening or rewriting it',
      (tester) async {
    late ScanFile original;
    await tester.runAsync(() async {
      original = await store.addBytes(sourceBytes, ScanKind.idCard, 'pdf',
          name: 'Printable');
    });
    await mount(tester);
    await tester.tap(find.text('Printable.pdf'));
    await waitFor(tester, find.text('Print'));
    await tester.tap(find.text('Print'));
    for (var attempt = 0; attempt < 100 && printing.printedBytes == null; attempt++) {
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(printing.printedBytes, orderedEquals(sourceBytes));
    expect(printing.printedName, 'Printable.pdf');
    expect(printing.lastDpi, isNull);
    expect(find.byType(DocumentReview), findsNothing);
    expect(store.files, hasLength(1));
    await tester.runAsync(() async {
      expect(await store.fileFor(original).readAsBytes(), orderedEquals(sourceBytes));
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the PDF picker does not create a document',
      (tester) async {
    pickedPath = null;
    await mount(tester);
    await importPdf(tester);
    expect(store.files, isEmpty);
    expect(find.byType(DocumentReview), findsNothing);
    expect(find.byTooltip('Scan'), findsOneWidget);
  });

  testWidgets('an empty PDF render reports an error and keeps the source',
      (tester) async {
    printing.pageCount = 0;
    await mount(tester);
    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import PDF'));
    await waitFor(tester,
        find.text('This PDF has no pages that can be opened.'));
    expect(find.byType(DocumentReview), findsNothing);
    await tester.runAsync(() async {
      expect(await source.readAsBytes(), orderedEquals(sourceBytes));
      expect(await cache.list().toList(), isEmpty);
    });
  });
}

class _TestPrinting extends PrintingPlatform {
  int pageCount = 2;
  double? lastDpi;
  Uint8List? printedBytes;
  String? printedName;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    printedName = name;
    printedBytes = await onLayout(format);
    return false; // Cancelling printing must not modify the saved file.
  }

  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    lastDpi = dpi;
    for (var index = 0; index < pageCount; index++) {
      yield _TestRaster();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected printing call: ${invocation.memberName}');
}

class _TestRaster extends PdfRaster {
  _TestRaster() : super(120, 80, Uint8List(120 * 80 * 4));

  @override
  Future<Uint8List> toPng() async => Uint8List.fromList(
      img.encodePng(img.Image(width: 120, height: 80, numChannels: 4)));
}
