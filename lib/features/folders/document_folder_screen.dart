import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/document_store.dart';
import '../../data/document_folders.dart';

const _blue = Color(0xFF205BC3);
const _ink = Color(0xFF294779);
const _muted = Color(0xFF8594AD);
const _background = Color(0xFFF4F7FD);

class DocumentFolderScreen extends StatefulWidget {
  const DocumentFolderScreen({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onAction,
    this.kind = ScanKind.document,
  });
  final ScanKind kind;
  final DocumentStore store;
  final Future<void> Function(ScanFile) onOpen;
  final Future<void> Function(ScanFile, String) onAction;
  @override
  State<DocumentFolderScreen> createState() => _DocumentFolderScreenState();
}

class _DocumentFolderScreenState extends State<DocumentFolderScreen> {
  late final folders = DocumentFolders(widget.store, kind: widget.kind);
  String? current;
  String query = '';
  String? loadError;
  bool loading = true, busy = false, selecting = false, searching = false;
  final selected = <String>{};
  final selectedFolders = <String>{};
  int get count => selected.length + selectedFolders.length;
  List<ScanFile> get files => widget.store.files
      .where(
        (f) =>
            f.kind == widget.kind &&
            folders.membership[f.id] == current &&
            f.filename.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();
  List<String> get folderIds => current == null
      ? folders.names.keys
            .where(
              (id) => folders.names[id]!.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList()
      : [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await folders.load();
    } catch (_) {
      loadError = 'Could not load folders. Please retry.';
    }
    if (mounted) setState(() => loading = false);
  }

  void notice(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      notice(
        e is FormatException
            ? e.message.toString()
            : 'Could not complete this action. Please try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clearSelection() => setState(() {
    selecting = false;
    selected.clear();
    selectedFolders.clear();
  });
  void toggle(String id, bool folder) => setState(() {
    selecting = true;
    final set = folder ? selectedFolders : selected;
    if (!set.add(id)) set.remove(id);
  });

  Future<String?> nameDialog(String title, [String initial = '']) async {
    var value = initial;
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: Form(
          key: key,
          child: TextFormField(
            initialValue: initial,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter File Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => value = v,
            validator: (v) {
              try {
                DocumentStore.validateName(v ?? '');
                return null;
              } on FormatException catch (e) {
                return e.message.toString();
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, value.trim());
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> createFolder() async {
    final name = await nameDialog('New Folder');
    if (name != null) await run(() => folders.create(name));
  }

  Future<void> menu({ScanFile? file, String? folder}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${widget.kind.label} Files',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.cancel, color: _muted),
                onPressed: () => Navigator.pop(c),
              ),
            ),
            for (final a in [
              'Rename',
              if (folder != null) 'Delete' else 'Download',
              if (file != null) 'Delete',
              'Select',
            ])
              ListTile(
                leading: Icon(switch (a) {
                  'Rename' => Icons.edit_outlined,
                  'Delete' => Icons.delete_outline,
                  'Download' => Icons.download_outlined,
                  _ => Icons.check_circle_outline,
                }),
                title: Text(a),
                onTap: () => Navigator.pop(c, a),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'Select') {
      toggle(file?.id ?? folder!, folder != null);
      return;
    }
    if (folder == null) {
      await run(() => widget.onAction(file!, action));
      return;
    }
    if (action == 'Rename') {
      final name = await nameDialog('Rename Folder', folders.names[folder]!);
      if (name != null) await run(() => folders.rename(folder, name));
    } else {
      setState(() {
        selected.clear();
        selectedFolders
          ..clear()
          ..add(folder);
        selecting = true;
      });
      await deleteSelected();
    }
  }

  List<ScanFile> get chosen => widget.store.files
      .where(
        (f) =>
            f.kind == widget.kind &&
            (selected.contains(f.id) ||
                selectedFolders.contains(folders.membership[f.id])),
      )
      .toList();

  Future<void> deleteSelected() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Item', textAlign: TextAlign.center),
        content: const Text(
          'Are you sure you want to delete the selected items? Selected folders and their files will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await run(() async {
      for (final file in chosen) {
        await widget.store.delete(file);
      }
      await folders.removeFolders(selectedFolders);
      await folders.move(selected, null);
      if (mounted) clearSelection();
    });
  }

  Future<void> moveSelected() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(c).height * .65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Move Files', textAlign: TextAlign.center),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.cancel_outlined),
                ),
              ),
              for (final id in ['', ...folders.names.keys])
                ListTile(
                  leading: const Icon(Icons.folder, color: _blue),
                  title: Text(
                    id.isEmpty ? widget.kind.label : folders.names[id]!,
                  ),
                  trailing: (id.isEmpty ? current == null : current == id)
                      ? const Icon(Icons.check_circle, color: _blue)
                      : null,
                  onTap: () => Navigator.pop(c, id),
                ),
            ],
          ),
        ),
      ),
    );
    if (target != null)
      await run(() async {
        await folders.move(selected, target.isEmpty ? null : target);
        if (mounted) clearSelection();
      });
  }

  Future<void> shareSelected() => run(() async {
    final box = context.findRenderObject()! as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        files: chosen.map((f) => XFile(widget.store.fileFor(f).path)).toList(),
        fileNameOverrides: chosen.map((f) => f.filename).toList(),
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });

  Future<void> mergeSelected() async {
    final name = await nameDialog('PDF');
    if (name == null) return;
    await run(() async {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: font, bold: font),
      );
      var pages = 0;
      // Rasterization is already used by the app's PDF editor. Originals stay intact.
      for (final file in chosen) {
        if (file.extension == 'txt') {
          final text = await widget.store.fileFor(file).readAsString();
          pdf.addPage(
            pw.MultiPage(
              maxPages: 100,
              build: (_) => [
                pw.Header(level: 1, text: file.name),
                pw.Paragraph(text: text),
              ],
            ),
          );
          pages++;
          continue;
        }
        await for (final page in Printing.raster(
          await widget.store.fileFor(file).readAsBytes(),
          dpi: 144,
        )) {
          if (++pages > 100)
            throw const FormatException(
              'Merge supports up to 100 pages at a time.',
            );
          final image = pw.MemoryImage(await page.toPng());
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width * .5, page.height * .5),
              margin: pw.EdgeInsets.zero,
              build: (_) =>
                  pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            ),
          );
        }
      }
      if (pages == 0)
        throw const FormatException('These files contain no readable pages.');
      final merged = await widget.store.addBytes(
        await pdf.save(),
        widget.kind,
        'pdf',
        name: name,
      );
      await folders.move([merged.id], current);
      if (mounted) {
        clearSelection();
        notice('Merged PDF saved. Original files retained.');
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, child) {
      final categoryFiles = widget.store.files
          .where((f) => f.kind == widget.kind)
          .toList();
      final validIds = categoryFiles.map((f) => f.id).toSet();
      final folderCounts = <String, int>{};
      for (final file in categoryFiles) {
        final folder = folders.membership[file.id];
        if (folder != null)
          folderCounts.update(folder, (count) => count + 1, ifAbsent: () => 1);
      }
      selected.removeWhere((id) => !validIds.contains(id));
      selectedFolders.removeWhere((id) => !folders.names.containsKey(id));
      final visibleFiles = files;
      final visibleFolders = folderIds;
      final all =
          count > 0 &&
          visibleFiles.every((f) => selected.contains(f.id)) &&
          visibleFolders.every(selectedFolders.contains);
      final onlyFiles = count > 0 && selectedFolders.isEmpty;
      return PopScope(
        canPop: current == null && !selecting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (selecting) {
              clearSelection();
            } else {
              setState(() {
                current = null;
                query = '';
              });
            }
          }
        },
        child: Scaffold(
          backgroundColor: _blue,
          appBar: AppBar(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(selecting ? Icons.close : Icons.arrow_back),
              onPressed: busy
                  ? null
                  : () {
                      if (selecting) {
                        clearSelection();
                      } else if (current != null) {
                        setState(() {
                          current = null;
                          query = '';
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
            ),
            titleSpacing: 0,
            title: Text(
              selecting
                  ? (count == 0 ? 'Select items' : '$count Selected')
                  : folders.names[current] ?? widget.kind.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            actions: selecting
                ? [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              selected.clear();
                              selectedFolders.clear();
                              if (!all) {
                                selected.addAll(visibleFiles.map((f) => f.id));
                                selectedFolders.addAll(visibleFolders);
                              }
                            }),
                      child: Text(
                        all ? 'Deselect all' : 'Select all',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ]
                : [
                    if (current == null)
                      IconButton(
                        tooltip: 'New folder',
                        icon: const Icon(Icons.create_new_folder_outlined),
                        onPressed: busy || loading || loadError != null
                            ? null
                            : createFolder,
                      ),
                    IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() {
                        searching = !searching;
                        query = '';
                      }),
                    ),
                  ],
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ColoredBox(
              color: _background,
              child: Column(
                children: [
                  if (busy) const LinearProgressIndicator(),
                  if (searching)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search files',
                        ),
                      ),
                    ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : loadError != null
                        ? Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  loading = true;
                                  loadError = null;
                                });
                                load();
                              },
                              child: Text(loadError!),
                            ),
                          )
                        : visibleFiles.isEmpty && visibleFolders.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No ${widget.kind.label.toLowerCase()} files yet'
                                  : 'No matching documents',
                              style: const TextStyle(color: _muted),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                            itemCount:
                                visibleFolders.length + visibleFiles.length,
                            itemBuilder: (_, index) {
                              if (index < visibleFolders.length) {
                                final id = visibleFolders[index];
                                return item(
                                  id: id,
                                  folder: true,
                                  title: folders.names[id]!,
                                  subtitle: '${folderCounts[id] ?? 0} Items',
                                );
                              }
                              final file =
                                  visibleFiles[index - visibleFolders.length];
                              return item(
                                id: file.id,
                                folder: false,
                                title: file.extension == 'txt'
                                    ? file.name
                                    : file.filename,
                                subtitle:
                                    '${file.extension == 'txt' ? '' : '${file.extension.toUpperCase()} • '}${size(file.bytes)} • ${age(file.created)}',
                                file: file,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  tool(
                    'Move',
                    Icons.folder_outlined,
                    onlyFiles ? moveSelected : null,
                  ),
                  tool(
                    'Share',
                    Icons.share_outlined,
                    onlyFiles ? shareSelected : null,
                  ),
                  tool(
                    'Merge',
                    Icons.copy_outlined,
                    onlyFiles &&
                            selected.length > 1 &&
                            chosen.every(
                              (f) => ['pdf', 'txt'].contains(f.extension),
                            )
                        ? mergeSelected
                        : null,
                  ),
                  tool(
                    'Delete',
                    Icons.delete_outline,
                    count > 0 ? deleteSelected : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget item({
    required String id,
    required bool folder,
    required String title,
    required String subtitle,
    ScanFile? file,
  }) {
    final checked = (folder ? selectedFolders : selected).contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          if (selecting)
            SizedBox(
              width: 30,
              child: Checkbox(
                value: checked,
                shape: const CircleBorder(),
                activeColor: _blue,
                onChanged: busy ? null : (_) => toggle(id, folder),
              ),
            ),
          Expanded(
            child: Material(
              color: checked ? const Color(0xFFE4EDFD) : _background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: checked ? const Color(0xFFCADBFA) : Colors.transparent,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onLongPress: busy ? null : () => toggle(id, folder),
                onTap: busy
                    ? null
                    : () {
                        if (selecting) {
                          toggle(id, folder);
                        } else if (folder) {
                          setState(() {
                            current = id;
                            query = '';
                            searching = false;
                          });
                        } else {
                          run(() => widget.onOpen(file!));
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 0, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 46,
                        decoration: BoxDecoration(
                          color: folder || file?.extension == 'txt'
                              ? Colors.white
                              : const Color(0xFFFFF1F2),
                          border: Border.all(
                            color: checked ? _blue : const Color(0xFFE6EAF2),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          folder
                              ? Icons.folder
                              : file?.extension == 'txt'
                              ? Icons.description_outlined
                              : Icons.picture_as_pdf_outlined,
                          color: folder
                              ? const Color(0xFF2E7BE6)
                              : file?.extension == 'txt'
                              ? const Color(0xFF344892)
                              : const Color(0xFFFF5067),
                          size: 31,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'More options for $title',
                        icon: const Icon(
                          Icons.more_vert,
                          color: _ink,
                          size: 20,
                        ),
                        onPressed: busy
                            ? null
                            : () =>
                                  menu(file: file, folder: folder ? id : null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tool(String label, IconData icon, VoidCallback? action) => Expanded(
    child: TextButton(
      onPressed: busy ? null : action,
      style: TextButton.styleFrom(
        foregroundColor: _blue,
        disabledForegroundColor: const Color(0xFFC5CBD5),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 23),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
  String size(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';
  String age(DateTime date) {
    final d = DateTime.now().difference(date);
    return d.inDays > 0
        ? '${d.inDays} days ago'
        : d.inHours > 0
        ? '${d.inHours} hours ago'
        : 'Just now';
  }
}
