import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum ScanKind {
  document('Document'),
  idCard('ID Card'),
  qr('QR Code'),
  barcode('Barcode');

  const ScanKind(this.label);
  final String label;
}

class ScanFile {
  const ScanFile({
    required this.id,
    required this.name,
    required this.kind,
    required this.extension,
    required this.created,
    required this.bytes,
  });
  final String id, name, extension;
  final ScanKind kind;
  final DateTime created;
  final int bytes;
  String get filename => '$name.$extension';
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'extension': extension,
    'created': created.toIso8601String(),
    'bytes': bytes,
  };
  factory ScanFile.fromJson(Map<String, dynamic> j) => ScanFile(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: ScanKind.values.byName(j['kind'] as String),
    extension: j['extension'] as String,
    created: DateTime.parse(j['created'] as String),
    bytes: j['bytes'] as int,
  );
}

/// Content and metadata live in app-owned storage, never scanner cache.
/// One metadata file per scan keeps unrelated records intact after a bad write.
class DocumentStore extends ChangeNotifier {
  DocumentStore(this.directory);
  final Directory directory;
  List<ScanFile> _files = [];
  List<ScanFile> get files => List.unmodifiable(_files);
  int unreadableRecords = 0;
  File fileFor(ScanFile doc) =>
      File('${directory.path}/${doc.id}.${doc.extension}');
  File _meta(String id) => File('${directory.path}/$id.json');

  Future<void> load({ValueChanged<double>? onProgress}) async {
    await directory.create(recursive: true);
    final loaded = <ScanFile>[];
    unreadableRecords = 0;
    final records = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .toList();
    onProgress?.call(0);
    var processed = 0;
    for (final entity in records.cast<File>()) {
      try {
        final doc = ScanFile.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        if (!RegExp(r'^\d+_[0-9a-f]+$').hasMatch(doc.id) ||
            !['pdf', 'txt'].contains(doc.extension) ||
            !await fileFor(doc).exists()) {
          throw const FormatException('Invalid or missing content');
        }
        loaded.add(doc);
      } catch (_) {
        unreadableRecords++;
      }
      processed++;
      // Reserve the final work unit for sorting and committing the list.
      onProgress?.call(processed / (records.length + 1));
    }
    loaded.sort((a, b) => b.created.compareTo(a.created));
    _files = loaded;
    onProgress?.call(1);
    notifyListeners();
  }

  static String validateName(String value) {
    final name = value.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(name) ||
        name.endsWith('.')) {
      throw const FormatException(
        'Use 1–100 characters without / \\ : * ? " < > |',
      );
    }
    return name;
  }

  Future<void> _writeMetadata(ScanFile doc) async {
    final temp = File('${_meta(doc.id).path}.tmp');
    await temp.writeAsString(jsonEncode(doc.toJson()), flush: true);
    await temp.rename(_meta(doc.id).path);
  }

  Future<ScanFile> addBytes(
    List<int> bytes,
    ScanKind kind,
    String extension, {
    String? name,
  }) async {
    if (!['pdf', 'txt'].contains(extension))
      throw ArgumentError('Unsupported format');
    final validatedName = name == null ? null : validateName(name);
    final now = DateTime.now();
    final id =
        '${now.microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
    final doc = ScanFile(
      id: id,
      name:
          validatedName ??
          '${kind.label.replaceAll(' ', '_')}_${now.toIso8601String().substring(0, 19).replaceAll(RegExp(r'[-:T]'), '')}',
      kind: kind,
      extension: extension,
      created: now,
      bytes: bytes.length,
    );
    await directory.create(recursive: true);
    await fileFor(doc).writeAsBytes(bytes, flush: true);
    try {
      await _writeMetadata(doc);
    } catch (_) {
      await fileFor(doc).delete();
      rethrow;
    }
    _files.insert(0, doc);
    notifyListeners();
    return doc;
  }

  /// Import a PDF through an app-owned copy; never move/delete the picked original.
  Future<ScanFile> importPdf(File source) async {
    final reader = await source.open();
    late final String header;
    try {
      header = latin1.decode(await reader.read(1024));
    } finally {
      await reader.close();
    }
    if (!RegExp(r'%PDF-(1\.[0-7]|2\.0)').hasMatch(header)) {
      throw const FormatException(
        'This file does not have a valid PDF header. Choose a PDF file.',
      );
    }
    var name = source.uri.pathSegments.last
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim();
    while (name.endsWith('.')) {
      name = name.substring(0, name.length - 1);
    }
    if (name.isEmpty) name = 'Imported document';
    if (name.length > 100) name = name.substring(0, 100);
    final now = DateTime.now();
    final id =
        '${now.microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
    await directory.create(recursive: true);
    final destination = File('${directory.path}/$id.pdf');
    try {
      // File.copy avoids loading the entire selected PDF into Dart memory.
      await source.copy(destination.path);
      final doc = ScanFile(
        id: id,
        name: name,
        kind: ScanKind.document,
        extension: 'pdf',
        created: now,
        bytes: await destination.length(),
      );
      await _writeMetadata(doc);
      _files.insert(0, doc);
      notifyListeners();
      return doc;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> rename(ScanFile doc, String value) async {
    final name = validateName(value);
    final updated = ScanFile(
      id: doc.id,
      name: name,
      kind: doc.kind,
      extension: doc.extension,
      created: doc.created,
      bytes: doc.bytes,
    );
    await _writeMetadata(updated);
    _files[_files.indexWhere((e) => e.id == doc.id)] = updated;
    notifyListeners();
  }

  /// Replace PDF bytes and metadata, restoring the previous PDF on failure.
  Future<ScanFile> replacePdf(ScanFile doc, List<int> bytes) async {
    final index = _files.indexWhere((f) => f.id == doc.id);
    if (index < 0 || doc.extension != 'pdf')
      throw StateError('Document unavailable');
    final target = fileFor(doc);
    final temp = File('${target.path}.new');
    final backup = File('${target.path}.backup');
    final updated = ScanFile(
      id: doc.id,
      name: doc.name,
      kind: doc.kind,
      extension: doc.extension,
      created: doc.created,
      bytes: bytes.length,
    );
    await temp.writeAsBytes(bytes, flush: true);
    await target.copy(backup.path);
    try {
      await temp.rename(target.path);
      await _writeMetadata(updated);
    } catch (_) {
      await backup.rename(target.path);
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    _files[index] = updated;
    notifyListeners();
    try {
      await backup.delete();
    } catch (_) {
      /* Durable new copy is saved. */
    }
    return updated;
  }

  Future<void> delete(ScanFile doc) async {
    // Remove content first: never report success while retaining the scan.
    if (await fileFor(doc).exists()) await fileFor(doc).delete();
    if (await _meta(doc.id).exists()) await _meta(doc.id).delete();
    _files.removeWhere((e) => e.id == doc.id);
    notifyListeners();
  }
}
