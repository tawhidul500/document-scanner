import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'page_editor.dart';
import 'editor_tools.dart';

/// Edits stay local to this route until Done returns the resulting page.
class DocumentEditor extends StatefulWidget {
  const DocumentEditor({
    super.key,
    required this.path,
    required this.name,
    required this.pageNumber,
    required this.pageCount,
    required this.directory,
    this.paperSize = 'original',
  });
  final String paperSize;
  final String path, name;
  final int pageNumber, pageCount;
  final Directory directory;

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  Uint8List? bytes;
  final history = <PageEditResult>[];
  late String paperSize = widget.paperSize;
  String? selected;
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await File(widget.path).readAsBytes();
      if (mounted)
        setState(() {
          bytes = data;
          busy = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'Could not open this page.';
          busy = false;
        });
    }
  }

  void commit(PageEditResult result) {
    if (identical(result.bytes, bytes) && result.paperSize == paperSize) return;
    setState(() {
      history.add(PageEditResult(bytes!, paperSize));
      if (history.length > 10) history.removeAt(0);
      bytes = result.bytes;
      paperSize = result.paperSize;
      error = null;
    });
  }

  Future<void> openTool(EditorTool tool, String label) async {
    if (busy || bytes == null) return;
    setState(() => selected = label);
    final result = await Navigator.of(context).push<PageEditResult>(
      MaterialPageRoute(
        builder: (_) => EditorToolScreen(
          tool: tool,
          bytes: bytes!,
          name: widget.name,
          paperSize: paperSize,
        ),
      ),
    );
    if (result != null && mounted) commit(result);
  }

  Future<void> crop() async {
    if (busy || bytes == null) return;
    setState(() {
      busy = true;
      selected = 'Crop';
    });
    File? temporary;
    try {
      temporary = File(
        '${widget.directory.path}/crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temporary.writeAsBytes(bytes!, flush: true);
      if (!mounted) return;
      final result = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PageEditor(path: temporary!.path)),
      );
      if (result != null && mounted) commit(PageEditResult(result, paperSize));
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not crop this page. Try again.');
    } finally {
      try {
        await temporary?.delete();
      } catch (_) {}
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: busy || bytes == null
                ? null
                : () => Navigator.pop(
                    context,
                    history.isEmpty ? null : PageEditResult(bytes!, paperSize),
                  ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, color: Color(0xFF4B68FF)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          Expanded(
            child: bytes == null
                ? const SizedBox.shrink()
                : DocumentImagePreview(bytes: bytes!, paperSize: paperSize),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '${widget.pageNumber}/${widget.pageCount}',
              style: const TextStyle(fontSize: 21, color: Colors.black87),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                action(Icons.crop, 'Crop', crop),
                action(
                  Icons.auto_awesome_outlined,
                  'Filters',
                  () => openTool(EditorTool.filter, 'Filters'),
                ),
                action(
                  Icons.open_in_full,
                  'Size',
                  () => openTool(EditorTool.resize, 'Size'),
                ),
                action(
                  Icons.crop_rotate,
                  'Rotate',
                  () => openTool(EditorTool.rotate, 'Rotate'),
                ),
                action(
                  Icons.undo,
                  'Undo',
                  history.isEmpty
                      ? null
                      : () => setState(() {
                          final previous = history.removeLast();
                          bytes = previous.bytes;
                          paperSize = previous.paperSize;
                          selected = 'Undo';
                          error = null;
                        }),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget action(IconData icon, String label, VoidCallback? callback) =>
      Expanded(
        child: TextButton(
          onPressed: busy || bytes == null ? null : callback,
          style: TextButton.styleFrom(
            foregroundColor: selected == label
                ? editorAccent
                : const Color(0xFF303030),
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );
}
