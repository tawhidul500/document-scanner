import '../../widgets/app_action_sheet.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import '../../widgets/reference_toolbar_surface.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import '../../data/document_store.dart';

class IdCardPreview extends StatefulWidget {
  const IdCardPreview({super.key, required this.store, required this.document,
    this.onOptions});
  final DocumentStore store;
  final ScanFile document;
  final Future<void> Function()? onOptions;
  @override
  State<IdCardPreview> createState() => _IdCardPreviewState();
}

class _IdCardPreviewState extends State<IdCardPreview> {
  late ScanFile document = widget.document;
  final previews = <Uint8List>[];
  int current = 0;
  bool showingSides = false;
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
      showingSides = false;
    });
    try {
      if (document.idCardSideCount > 0) {
        final sides = <Uint8List>[];
        for (var i=0;i<document.idCardSideCount;i++) {
          final side=widget.store.idCardSideFor(document,i);
          if (await side.exists()) sides.add(await side.readAsBytes());
        }
        if (sides.length == document.idCardSideCount) {
          if (mounted) setState(() { showingSides=true; previews.addAll(sides); });
          return;
        }
      }
      // Older scans without side images keep their original PDF sheet preview.
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
    if (widget.onOptions != null) {
      await widget.onOptions!();
      if (!mounted) return;
      document = widget.store.files.firstWhere((file) => file.id == document.id);
      await load();
      return;
    }
    final selected = await showAppActionSheet<String>(
      context: context,
      title: const AppText('ID Card Options'),
      actions: (sheetContext) => [
        for (final item in [
          (Icons.edit_outlined, 'Rename'),
          (Icons.file_download_outlined, 'Download'),
          (Icons.picture_as_pdf_outlined, 'Export as PDF'),
        ])
          AppMenuAction(
            icon: item.$1,
            label: item.$2,
            onTap: () => Navigator.pop(sheetContext, item.$2),
          ),
      ],
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
            const SnackBar(content: AppText('ID card PDF exported.')),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Could not export this file. Please retry.'),
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
          title: const AppText('Rename ID card'),
          content: TextField(
            controller: name,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: context.tr('File name'),
              suffixText: '.pdf',
              errorText: context.trOrNull(validation),
              errorMaxLines: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            TextButton(
              onPressed: () {
                try {
                  Navigator.pop(context, DocumentStore.validateName(name.text));
                } on FormatException catch (e) {
                  update(() => validation = e.message);
                }
              },
              child: const AppText('Save'),
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
          const SnackBar(content: AppText('Could not rename this file.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: AppBar(
        backgroundColor: AppPalette.of(context).surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppText(
          'ID Card Preview',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : options,
            child: AppText(
              'Option',
              style: TextStyle(color: AppPalette.of(context).primary),
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
                        AppText(error!),
                        TextButton(onPressed: load, child: const AppText('Retry')),
                      ],
                    ),
                  )
                : previews.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : showingSides
                ? IdCardSidesPreview(sides: previews)
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
          if (!showingSides && previews.length > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppText('${current + 1}/${previews.length}'),
            ),
        ],
      ),
      bottomNavigationBar: const ReferenceToolbarSurface(
        child: SafeArea(top: false, child: SizedBox(height: 46)),
      ),
    ),
  );
}

/// Front/back are card surfaces, not document pages or a stretched A4 preview.
class IdCardSidesPreview extends StatelessWidget {
  const IdCardSidesPreview({super.key, required this.sides})
    : assert(sides.length > 0 && sides.length <= 2);
  final List<Uint8List> sides;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24,24,24,32),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:420),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
        AppText(sides.length == 1 ? 'One side' : 'Both side',textAlign:TextAlign.center,
          style: TextStyle(fontSize:13,color:AppPalette.of(context).secondary)),
        const SizedBox(height:24),
        for (var i=0;i<sides.length;i++) ...[
          AppText(i == 0 ? 'Front side' : 'Back side',
            style: TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:AppPalette.of(context).text)),
          const SizedBox(height:10),
          Container(
            key:ValueKey('id-card-side-$i'),
            decoration: BoxDecoration(color:AppPalette.of(context).surface,borderRadius:BorderRadius.circular(12),
              border:Border.all(color:AppPalette.of(context).outline),
              boxShadow:const [BoxShadow(color:Color(0x120F2A5C),blurRadius:14,offset:Offset(0,5))]),
            child: ClipRRect(borderRadius:BorderRadius.circular(11),
              child: AspectRatio(aspectRatio:85.6/54,
                child: InteractiveViewer(minScale:1,maxScale:4,
                  child: Image.memory(sides[i],fit:BoxFit.contain,
                    semanticLabel:context.tr(i == 0 ? 'Front of ID card' : 'Back of ID card')))))),
          const SizedBox(height:28),
        ],
      ]))),
  );
}
