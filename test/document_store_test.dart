import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';

void main() {
  late Directory directory;
  late DocumentStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('scanner_test_');
    store = DocumentStore(directory);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'Unicode code content, rename and delete persist across restarts',
    () async {
      const text = 'বাংলা QR content — https://example.com';
      final doc = await store.addBytes(utf8.encode(text), ScanKind.qr, 'txt');
      await store.rename(doc, 'My code');
      final reopened = DocumentStore(directory);
      await reopened.load();
      expect(reopened.files.single.filename, 'My code.txt');
      expect(
        await reopened.fileFor(reopened.files.single).readAsString(),
        text,
      );
      await reopened.delete(reopened.files.single);
      await reopened.load();
      expect(reopened.files, isEmpty);
      reopened.dispose();
    },
  );

  test('one corrupt metadata record does not hide valid scans', () async {
    await store.addBytes(utf8.encode('12345'), ScanKind.barcode, 'txt');
    await File('${directory.path}/broken.json').writeAsString('{');
    await store.load();
    expect(store.files, hasLength(1));
    expect(store.unreadableRecords, 1);
    expect(await File('${directory.path}/broken.json').exists(), isTrue);
  });

  test('invalid names cannot become export paths', () {
    for (final name in [
      '',
      '../secret',
      'a/b',
      'a\\b',
      'trailing.',
      'bad:name',
    ]) {
      expect(() => DocumentStore.validateName(name), throwsFormatException);
    }
    expect(DocumentStore.validateName('  Receipt  '), 'Receipt');
  });
  test(
    'PDF import keeps original name and survives removal of source',
    () async {
      final source = File('${directory.path}/Receipt.PDF');
      final content = latin1.encode('%PDF-1.7\nfixture header only\n%%EOF');
      await source.writeAsBytes(content);
      final imported = await store.importPdf(source);
      expect(imported.filename, 'Receipt.pdf');
      expect(imported.kind, ScanKind.document);
      expect(await source.exists(), isTrue);
      await source.delete();
      expect(await store.fileFor(imported).readAsBytes(), content);
      await store.load();
      expect(store.files.single.filename, 'Receipt.pdf');
    },
  );

  test('PDF filter checks bytes and rejects a renamed text file', () async {
    final source = File('${directory.path}/fake.pdf');
    await source.writeAsString('This is plain text, not a PDF.');
    await expectLater(store.importPdf(source), throwsFormatException);
    expect(store.files, isEmpty);
    expect(await source.exists(), isTrue);
  });

  test(
    'load progress includes corrupt records and completes after committing',
    () async {
      await store.addBytes(utf8.encode('hello'), ScanKind.qr, 'txt');
      await File('${directory.path}/broken.json').writeAsString('{');
      final values = <double>[];
      await store.load(
        onProgress: (value) {
          values.add(value);
          if (value == 1) expect(store.files, hasLength(1));
        },
      );
      expect(values, [0.0, 1 / 3, 2 / 3, 1.0]);
      expect(store.unreadableRecords, 1);
    },
  );

  test('empty store finishes without an animation delay', () async {
    final values = <double>[];
    await store.load(onProgress: values.add);
    expect(values, [0.0, 1.0]);
  });

  test(
    'replacing PDF preserves identity and updated size across restart',
    () async {
      final doc = await store.addBytes(
        utf8.encode('%PDF-1.7 old'),
        ScanKind.document,
        'pdf',
      );
      final bytes = utf8.encode('%PDF-1.7 replacement contents');
      final updated = await store.replacePdf(doc, bytes);
      expect(updated.id, doc.id);
      expect(updated.name, doc.name);
      expect(updated.bytes, bytes.length);
      await store.load();
      expect(store.files.single.bytes, bytes.length);
      expect(await store.fileFor(updated).readAsBytes(), bytes);
    },
  );
}
