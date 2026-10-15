import 'dart:convert';
import 'dart:io';
import 'document_store.dart';

/// Folder membership is separate from scan metadata for backwards compatibility.
class DocumentFolders {
  DocumentFolders(this.store, {this.kind = ScanKind.document});
  final ScanKind kind;
  final DocumentStore store;
  Map<String, String> names = {};
  Map<String, String> membership = {};
  File get file => File(
    '${store.directory.path}/folders/${kind == ScanKind.document ? 'index' : kind.name}.json',
  );

  Future<void> load() async {
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    names = Map<String, String>.from(json['names'] as Map);
    membership = Map<String, String>.from(json['membership'] as Map);
  }

  Future<void> save() async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'names': names, 'membership': membership}),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<void> commit(
    Map<String, String> nextNames,
    Map<String, String> nextMembership,
  ) async {
    final oldNames = names;
    final oldMembership = membership;
    names = nextNames;
    membership = nextMembership;
    try {
      await save();
    } catch (_) {
      names = oldNames;
      membership = oldMembership;
      rethrow;
    }
  }

  Future<void> create(String name) async {
    name = DocumentStore.validateName(name);
    if (names.values.any((n) => n.toLowerCase() == name.toLowerCase())) {
      throw const FormatException('A folder with this name already exists.');
    }
    await commit(
      {...names, DateTime.now().microsecondsSinceEpoch.toString(): name},
      {...membership},
    );
  }

  Future<void> rename(String id, String name) async {
    name = DocumentStore.validateName(name);
    if (names.entries.any(
      (e) => e.key != id && e.value.toLowerCase() == name.toLowerCase(),
    )) {
      throw const FormatException('A folder with this name already exists.');
    }
    await commit({...names, id: name}, {...membership});
  }

  Future<void> move(Iterable<String> ids, String? destination) async {
    if (destination != null && !names.containsKey(destination))
      throw StateError('Folder unavailable');
    final allowed = store.files
        .where((f) => f.kind == kind)
        .map((f) => f.id)
        .toSet();
    if (destination != null && ids.any((id) => !allowed.contains(id))) {
      throw StateError('Files must belong to this category');
    }
    final next = {...membership};
    for (final id in ids) {
      if (destination == null) {
        next.remove(id);
      } else {
        next[id] = destination;
      }
    }
    await commit({...names}, next);
  }

  Future<void> removeFolders(Set<String> ids) async {
    final next = {...names}..removeWhere((id, _) => ids.contains(id));
    final members = {...membership}
      ..removeWhere((_, folder) => ids.contains(folder));
    await commit(next, members);
  }
}
