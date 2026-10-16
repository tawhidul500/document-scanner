import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/document_store.dart';

void main() {
  test('card sides survive reopening and rename, and are removed with the ID', () async {
    final directory=await Directory.systemTemp.createTemp('id_sides_');
    final store=DocumentStore(directory);
    try {
      await store.load();
      final doc=await store.addBytes([37,80,68,70],ScanKind.idCard,'pdf',
        idCardSides:[[1,2,3],[4,5,6]]);
      await store.load();
      final reopened=store.files.single;
      expect(reopened.idCardSideCount,2);
      expect(await store.idCardSideFor(reopened,0).readAsBytes(),[1,2,3]);
      expect(await store.idCardSideFor(reopened,1).readAsBytes(),[4,5,6]);
      await store.rename(reopened,'My ID');
      expect(store.files.single.idCardSideCount,2);
      await store.delete(store.files.single);
      expect(await store.idCardSideFor(doc,0).exists(),isFalse);
      expect(await store.idCardSideFor(doc,1).exists(),isFalse);
      expect(store.files,isEmpty);
    } finally { store.dispose(); await directory.delete(recursive:true); }
  });

  test('storage rejects a third side before creating content', () async {
    final directory=await Directory.systemTemp.createTemp('id_limit_');
    final store=DocumentStore(directory);
    try {
      await expectLater(store.addBytes([1],ScanKind.idCard,'pdf',
        idCardSides:[[1],[2],[3]]),throwsArgumentError);
      expect(await directory.list().toList(),isEmpty);
    } finally { store.dispose(); await directory.delete(recursive:true); }
  });
}
