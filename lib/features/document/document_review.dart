import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/document_store.dart';
import 'document_camera.dart';
import 'document_editor.dart';
import 'editor_tools.dart';
import 'editor_processing.dart';
import 'signature_editor.dart';
import 'page_processing.dart';
import 'recognize_text.dart';

class DocumentReview extends StatefulWidget {
  const DocumentReview({
    super.key,
    required this.pages,
    required this.directory,
    required this.store,
    required this.document,
  });
  final List<String> pages;
  final Directory directory;
  final DocumentStore store;
  final ScanFile document;
  @override
  State<DocumentReview> createState() => _DocumentReviewState();
}

class _DocumentReviewState extends State<DocumentReview> {
  late final List<String> pages = List.of(widget.pages);
  final paperSizes = <String, String>{};
  late ScanFile document = widget.document;
  final pager = PageController();
  int current = 0, revision = 0;
  String? selectedAction;
  bool busy = false, dirty = false, leaving = false;
  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> persist() async {
    final bytes = await compute(buildEditedPdfFromPaths, <String, Object>{
      'pages': List<String>.of(pages),
      'sizes': pages.map((path) => paperSizes[path] ?? 'a4').toList(),
    });
    document = await widget.store.replacePdf(document, bytes);
    dirty = false;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      message(
        dirty
            ? 'Changes could not be saved. Use Option > Save changes to retry.'
            : 'Could not complete this action. Check available storage and retry.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    if (dirty) {
      await run(persist);
      if (dirty) return;
    }
    if (mounted) {
      leaving = true;
      Navigator.pop(context);
    }
  }

  Future<void> updatePage(Uint8List bytes, {String? paperSize}) async {
    final file = File(
      '${widget.directory.path}/edit_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    setState(() {
      final previousPath = pages[current];
      paperSizes[file.path] = paperSize ?? paperSizes[previousPath] ?? 'a4';
      paperSizes.remove(previousPath);
      pages[current] = file.path;
      dirty = true;
      revision++;
    });
    await persist();
  }

  Future<void> sign() async {
    if (busy) return;
    final result = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => SignatureEditor(path: pages[current])),
    );
    if (result != null && mounted) await run(() => updatePage(result));
  }

  Future<void> openEditor() async {
    if (busy) return;
    final result = await Navigator.of(context).push<PageEditResult>(
      MaterialPageRoute(
        builder: (_) => DocumentEditor(
          path: pages[current],
          name: document.name,
          pageNumber: current + 1,
          pageCount: pages.length,
          directory: widget.directory,
          paperSize: paperSizes[pages[current]] ?? 'a4',
        ),
      ),
    );
    if (result != null && mounted)
      await run(() => updatePage(result.bytes, paperSize: result.paperSize));
  }

  Future<void> showOptions() async {
    if (busy) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Document Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  Positioned(
                    right: 8,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.cancel, color: Color(0xFF989DA5)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F1F1)),
            for (final item in [
              (Icons.edit_outlined, 'Rename', 'Rename'),
              (Icons.file_download_outlined, 'Download', 'Export PDF'),
              (Icons.picture_as_pdf_outlined, 'Export as PDF', 'Export PDF'),
            ]) ...[
              ListTile(
                dense: true,
                minTileHeight: 40,
                leading: Icon(item.$1, color: Colors.black),
                title: Text(item.$2, style: const TextStyle(fontSize: 16)),
                onTap: () => Navigator.pop(sheetContext, item.$3),
              ),
              const Divider(height: 1, indent: 64, color: Color(0xFFF1F1F1)),
            ],
            if (dirty)
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, 'Save changes'),
                child: const Text('Save changes'),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await option(selected);
  }

  Future<void> rename() async {
    final controller = TextEditingController(text: document.name);
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('Rename document'),
          content: SizedBox(
            width: 300,
            height: 120,
            child: TextField(
              controller: controller,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'File name',
                suffixText: '.pdf',
                helperText: ' ',
                errorText: validation,
                errorMaxLines: 2,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.pop(c, DocumentStore.validateName(controller.text));
                } on FormatException catch (e) {
                  setDialog(() => validation = e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog route may still be animating out.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (result != null && mounted)
      await run(() async {
        await widget.store.rename(document, result);
        document = widget.store.files.firstWhere((f) => f.id == document.id);
      });
  }

  Future<void> option(String value) async {
    if (busy) return;
    switch (value) {
      case 'Rename':
        await rename();
      case 'Save changes':
        await run(persist);
      case 'Add pages':
        if (pages.length >= 50) {
          message('This document has reached the 50-page limit.');
          return;
        }
        final extra = await Navigator.of(context).push<List<String>>(
          MaterialPageRoute(
            builder: (_) => DocumentCamera(
              directory: widget.directory,
              remaining: 50 - pages.length,
            ),
          ),
        );
        if (extra != null && extra.isNotEmpty && mounted)
          await run(() async {
            setState(() {
              pages.addAll(extra);
              dirty = true;
            });
            await persist();
          });
      case 'Rotate page':
        await run(() async {
          final bytes = await File(pages[current]).readAsBytes();
          await updatePage(
            await compute(processPage, <String, Object>{
              'bytes': bytes,
              'rotate': true,
            }),
          );
        });
      case 'Delete page':
        if (pages.length == 1) {
          message('Keep at least one page in the document.');
          return;
        }
        final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete this page?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (yes == true && mounted)
          await run(() async {
            setState(() {
              pages.removeAt(current);
              if (current >= pages.length) current = pages.length - 1;
              dirty = true;
            });
            pager.jumpToPage(current);
            await persist();
          });
      case 'Export PDF':
        await run(() async {
          if (dirty) await persist();
          final path = await FlutterFileDialog.saveFile(
            params: SaveFileDialogParams(
              sourceFilePath: widget.store.fileFor(document).path,
              fileName: document.filename,
            ),
          );
          if (path != null) message('PDF exported.');
        });
    }
  }

  Future<void> share() => run(() async {
    if (dirty) await persist();
    if (!mounted) return;
    final box = context.findRenderObject()! as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.store.fileFor(document).path)],
        fileNameOverrides: [document.filename],
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });
  Future<void> convert() async {
    if (busy) return;
    setState(() => selectedAction = 'Convert');
    final saved = await Navigator.of(context).push<ScanFile>(
      MaterialPageRoute(
        builder: (_) =>
            RecognizeTextScreen(path: pages[current], store: widget.store),
      ),
    );
    if (saved != null && mounted)
      message('${saved.filename} saved to Documents.');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) close();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: busy ? null : close,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          document.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : showOptions,
            child: const Text(
              'Option',
              style: TextStyle(color: Color(0xFF0055FF), fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: PageView.builder(
              controller: pager,
              itemCount: pages.length,
              onPageChanged: (value) => setState(() => current = value),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(28, 35, 28, 16),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: pageImage(pages[i]),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '${current + 1}/${pages.length}',
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
                action(Icons.share_outlined, 'Share', share),
                action(Icons.edit_note_outlined, 'Edit', openEditor),
                action(Icons.document_scanner_outlined, 'Convert', convert),
                action(Icons.draw_outlined, 'Sign', sign),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget pageImage(String path) {
    Widget image = Image.file(
      File(path),
      key: ValueKey('${path}_$revision'),
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) =>
          const Text('Could not display this page.'),
    );
    final paper = paperSizes[path];
    if (paper != null && paper != 'original') {
      final dimensions = documentPaperSize(paper, 1, 1);
      image = AspectRatio(
        aspectRatio: dimensions[0] / dimensions[1],
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: image),
        ),
      );
    }
    return image;
  }

  Widget action(IconData icon, String label, VoidCallback callback) =>
      TextButton(
        onPressed: busy
            ? null
            : () {
                setState(() => selectedAction = label);
                callback();
              },
        style: TextButton.styleFrom(
          foregroundColor: selectedAction == label
              ? const Color(0xFF5262FF)
              : Colors.black,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 27),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      );
}

Future<Uint8List> buildPdfFromPaths(List<String> pages) async {
  final images = <Uint8List>[];
  for (final path in pages) images.add(await File(path).readAsBytes());
  return buildDocumentPdf(images);
}

Future<Uint8List> buildEditedPdfFromPaths(Map<String, Object> request) async {
  final images = <Uint8List>[];
  for (final path in request['pages'] as List<String>) {
    images.add(await File(path).readAsBytes());
  }
  return buildDocumentPdf(images, paperSizes: request['sizes'] as List<String>);
}
