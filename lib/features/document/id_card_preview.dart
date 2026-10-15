import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import '../../data/document_store.dart';

class IdCardPreview extends StatefulWidget {
  const IdCardPreview({super.key, required this.store, required this.document});
  final DocumentStore store;
  final ScanFile document;
  @override
  State<IdCardPreview> createState() => _IdCardPreviewState();
}

class _IdCardPreviewState extends State<IdCardPreview> {
  late ScanFile document = widget.document;
  final previews = <Uint8List>[];
  int current = 0;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      error = null;
      previews.clear();
      current = 0;
    });
    try {
      final bytes = await widget.store.fileFor(document).readAsBytes();
      final rendered = <Uint8List>[];
      await for (final page in Printing.raster(bytes, dpi: 144)) {
        final image = await page.toPng();
        rendered.add(image);
      }
      if (rendered.isEmpty) throw const FormatException('No PDF page');
      if (mounted) setState(() => previews.addAll(rendered));
    } catch (_) {
      if (mounted) setState(() => error = 'Could not display this ID card.');
    }
  }

  Future<void> options() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
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
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in [
              (Icons.edit_outlined, 'Rename'),
              (Icons.file_download_outlined, 'Download'),
              (Icons.picture_as_pdf_outlined, 'Export as PDF'),
            ]) ...[
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: Icon(item.$1),
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$2),
              ),
            ],
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == 'Rename') {
      await rename();
    } else {
      setState(() => busy = true);
      try {
        final saved = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
            sourceFilePath: widget.store.fileFor(document).path,
            fileName: document.filename,
          ),
        );
        if (saved != null && mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID card PDF exported.')),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not export this file. Please retry.'),
            ),
          );
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> rename() async {
    final name = TextEditingController(text: document.name);
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Rename document'),
          content: TextField(
            controller: name,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'File name',
              suffixText: '.pdf',
              errorText: validation,
              errorMaxLines: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                try {
                  Navigator.pop(context, DocumentStore.validateName(name.text));
                } on FormatException catch (e) {
                  update(() => validation = e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.rename(document, result);
      if (mounted)
        setState(
          () => document = widget.store.files.firstWhere(
            (file) => file.id == document.id,
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not rename this file.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'ID Card Image Preview',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : options,
            child: const Text(
              'Option',
              style: TextStyle(color: Color(0xFF5262FF)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : previews.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    itemCount: previews.length,
                    onPageChanged: (index) => setState(() => current = index),
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(23, 40, 23, 16),
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Image.memory(
                            previews[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (previews.length > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${current + 1}/${previews.length}'),
            ),
        ],
      ),
      bottomNavigationBar: const ColoredBox(
        color: Colors.white,
        child: SafeArea(top: false, child: SizedBox(height: 46)),
      ),
    ),
  );
}
