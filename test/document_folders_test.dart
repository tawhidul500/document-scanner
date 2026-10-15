import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/data/document_folders.dart';

void main() {
  test(
    'folders persist without changing scans or polluting scan metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp('folder_test_');
      final store = DocumentStore(directory);
      try {
        final scan = await store.addBytes([1, 2, 3], ScanKind.document, 'pdf');
        final folders = DocumentFolders(store);
        await folders.create('Work Report');
        final id = folders.names.keys.single;
        await folders.move([scan.id], id);
        await folders.rename(id, 'Reports');
        final reloaded = DocumentFolders(store);
        await reloaded.load();
        expect(reloaded.names[id], 'Reports');
        expect(reloaded.membership[scan.id], id);
        await store.load();
        expect(store.unreadableRecords, 0);
        expect(store.files.single.id, scan.id);
        expect(await store.fileFor(scan).readAsBytes(), [1, 2, 3]);
        await expectLater(reloaded.create('reports'), throwsFormatException);
        await reloaded.move([scan.id], null);
        await reloaded.removeFolders({id});
        final finalFolders = DocumentFolders(store);
        await finalFolders.load();
        expect(finalFolders.names, isEmpty);
        expect(finalFolders.membership, isEmpty);
        expect(await store.fileFor(scan).exists(), isTrue);
      } finally {
        store.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
