import '../../widgets/app_toolbar_action.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_action_icon.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../data/document_store.dart';
import '../../data/document_folders.dart';
import '../../widgets/reference_toolbar_surface.dart';
import '../../widgets/reference_navigation.dart';
import '../../widgets/scan_empty_state.dart';
import '../../widgets/file_thumbnail.dart';
import '../scan/scanner_session.dart';
import '../settings/settings_screen.dart';
import '../folders/document_folder_screen.dart';
import 'camera_action_menu.dart';
import 'file_actions_sheet.dart';
import '../document/document_review.dart';
import '../document/id_card_preview.dart';
import '../document/id_card_processing.dart';
import '../document/recognize_text.dart';

const ink = Color(0xFF0F2A5C);
const blue = Color(0xFF1C59C1);
const accent = Color(0xFF4B68FF);
const pale = Color(0xFFF6F9FE);
const line = Color(0xFFE3E9F3);
const muted = Color(0xFF6B7A90);
const tileColors = [
  Color(0xFFEAF2FF),
  Color(0xFFE9F8EF),
  Color(0xFFF2EBFF),
  Color(0xFFFFF3E5),
];

typedef FileAction = Future<void> Function(ScanFile, String);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final DocumentStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool busy = false;
  bool menuOpen = false;
  bool fileMenuOpen = false;
  final cameraButtonKey = GlobalKey();
  final scrollController = ScrollController();
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  DocumentStore get store => widget.store;

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(text)));
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } on FormatException catch (error) {
      message(error.message);
    } catch (_) {
      message(
        'Could not complete this action. Check camera access or available storage and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan(ScanKind initialKind) => run(() async {
    final cache = await getTemporaryDirectory();
    final session = await cache.createTemp('document_session_');
    var kind = initialKind;
    try {
      if (!mounted) return;
      final result = await Navigator.of(context).push<Object>(MaterialPageRoute(
        builder: (_) => ScannerSession(directory: session, initialKind: initialKind,
          onKindChanged: (value) => kind=value)));
      if (result == null || !mounted) return;
      if (result is String && (kind == ScanKind.qr || kind == ScanKind.barcode)) {
        final saved = await store.addBytes(utf8.encode(result), kind, 'txt');
        if (mounted) await open(saved);
        return;
      }
      if (result is! List<String> || result.isEmpty) return;
      final pages=result;
      final bytes = kind == ScanKind.idCard
          ? await compute(buildIdCardPdf, pages) : await compute(buildPdfFromPaths, pages);
      final sides = kind == ScanKind.idCard
          ? await Future.wait(pages.map((path) => File(path).readAsBytes()))
          : <Uint8List>[];
      final doc = await store.addBytes(bytes, kind, 'pdf', idCardSides: sides);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => kind == ScanKind.idCard
        ? IdCardPreview(store: store, document: doc)
        : DocumentReview(pages: pages, directory: session, store: store, document: doc)));
    } finally {
      try { await session.delete(recursive: true); } catch (_) {}
    }
  });

  Future<void> chooseScan() async {
    if (busy || menuOpen) return;
    final box =
        cameraButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => menuOpen = true);
    CameraAction? action;
    try {
      action = await showCameraActionMenu(context, anchor);
    } finally {
      if (mounted) setState(() => menuOpen = false);
    }
    if (!mounted || action == null) return;
    switch (action) {
      case CameraAction.document:
        await scan(ScanKind.document);
      case CameraAction.idCard:
        await scan(ScanKind.idCard);
      case CameraAction.qr:
        await scan(ScanKind.qr);
      case CameraAction.barcode:
        await scan(ScanKind.barcode);
      case CameraAction.importPdf:
        await importPdf();
    }
  }

  Future<void> importPdf() => run(() async {
    final path = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        allowedUtiTypes: ['com.adobe.pdf'],
        mimeTypesFilter: ['application/pdf'],
        fileExtensionsFilter: ['pdf'],
        copyFileToCacheDir: true,
      ),
    );
    if (path == null) return;
    try {
      final doc = await store.importPdf(File(path));
      if (mounted) await reviewDocument(doc);
    } on FormatException catch (e) {
      message(e.message);
    }
  });

  Future<void> open(ScanFile doc) async {
    if (fileMenuOpen || !mounted) return;
    try {
      fileMenuOpen = true;
      String? action;
      try {
        doc = currentDocument(doc);
        if (!await store.fileFor(doc).exists()) {
          throw const FormatException('This file is no longer available.');
        }
        if (!mounted) return;
        action = await showFileActions(context, doc);
      } finally {
        fileMenuOpen = false;
      }
      if (action != null && mounted) await performFileAction(doc, action);
    } on FormatException catch (error) {
      message(error.message);
    } catch (_) {
      message('Could not open this file action. Please try again.');
    }
  }

  ScanFile currentDocument(ScanFile doc) => store.files.firstWhere(
    (file) => file.id == doc.id,
    orElse: () => throw const FormatException('This file is no longer available.'),
  );

  Future<Uint8List> printableBytes(ScanFile doc) async {
    final file = store.fileFor(doc);
    if (doc.extension == 'pdf') return file.readAsBytes();
    final font = await rootBundle.load('assets/fonts/Inter.ttf');
    return buildRecognizedTextPdf(await file.readAsString(), font);
  }

  // This is also called from a preview while Home is awaiting that route.
  // Do not nest Home.run here: its busy flag remains set during navigation.
  Future<void> performFileAction(ScanFile doc, String action) async {
    doc = currentDocument(doc);
    if (!await store.fileFor(doc).exists()) {
      throw const FormatException('This file is no longer available.');
    }
    if (!mounted) return;
    switch (action) {
      case 'Open document actions':
        await reviewDocument(doc);
      case 'Preview':
        await preview(doc);
      case 'Print':
        final bytes = await printableBytes(doc);
        if (!mounted) return;
        await Printing.layoutPdf(
          name: '${doc.name}.pdf',
          dynamicLayout: false,
          onLayout: (_) async => bytes,
        );
      case 'Share':
        final box = context.findRenderObject()! as RenderBox;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(store.fileFor(doc).path)],
            fileNameOverrides: [doc.filename],
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      case 'Download':
      case 'Export':
        final saved = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
            sourceFilePath: store.fileFor(doc).path,
            fileName: doc.filename,
          ),
        );
        if (saved != null) message('File exported successfully.');
    }
  }

  Future<void> preview(ScanFile doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => doc.kind == ScanKind.idCard && doc.extension == 'pdf'
            ? IdCardPreview(store: store, document: doc,
                onOptions: () => open(doc))
            : DocumentPreview(document: doc, file: store.fileFor(doc), store: store,
                onOptions: () => open(doc)),
      ),
    );
  }

  Future<void> reviewDocument(ScanFile doc) async {
    final cache = await getTemporaryDirectory();
    final session = await cache.createTemp('document_review_');
    try {
      final pages = <String>[];
      final bytes = await printableBytes(doc);
      await for (final page in Printing.raster(bytes, dpi: 144)) {
        if (pages.length >= 50) {
          throw const FormatException(
            'Document exceeds the 50-page editing limit.',
          );
        }
        final image = File('${session.path}/page_${pages.length}.png');
        await image.writeAsBytes(await page.toPng(), flush: true);
        pages.add(image.path);
      }
      if (pages.isEmpty) {
        throw const FormatException('This PDF has no pages that can be opened.');
      }
      if (!mounted) return;
      // Validate rendering before creating a copy. Never replace a text scan.
      if (doc.extension == 'txt') {
        doc = await store.addBytes(bytes, ScanKind.document, 'pdf', name: doc.name);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReview(
            pages: pages,
            directory: session,
            store: store,
            document: doc,
            defaultPaperSize: 'original',
          ),
        ),
      );
    } finally {
      try {
        await session.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> fileAction(ScanFile doc, String action) async {
    if (action == 'Rename') {
      final controller = TextEditingController(text: doc.name);
      final form = GlobalKey<FormState>();
      final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const AppText('Rename file'),
          content: Form(
            key: form,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: context.tr('File name'),
                suffixText: '.${doc.extension}',
              ),
              validator: (v) {
                try {
                  DocumentStore.validateName(v ?? '');
                  return null;
                } on FormatException catch (e) {
                  return context.tr(e.message);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate())
                  Navigator.pop(c, controller.text);
              },
              child: const AppText('Save'),
            ),
          ],
        ),
      );
      // Let the closing dialog finish using its editing controller.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      if (name != null && mounted) await run(() => store.rename(doc, name));
    } else if (action == 'Delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const AppText('Delete file?'),
          content: AppText(
            'Delete {filename} from this app? Exported copies will remain.',
            arguments: {'filename': doc.filename},
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: AppText('Delete', style: TextStyle(color: AppPalette.of(context).danger)),
            ),
          ],
        ),
      );
      if (yes == true && mounted) await run(() => store.delete(doc));
    } else {
      await run(() => performFileAction(doc, action));
    }
  }

  void browse({ScanKind? kind, bool search = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => kind != null
            ? DocumentFolderScreen(
                store: store,
                onScan: chooseScan,
                kind: kind,
                onOpen: open,
                onAction: fileAction,
              )
            : RecentFilesScreen(
                store: store,
                onScan: chooseScan,
                autofocus: search,
                onOpen: open,
                onAction: fileAction,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppPalette.of(context).surface,
      systemNavigationBarIconBrightness: AppPalette.of(context).dark ? Brightness.light : Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: AppPalette.of(context).header,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: 67 * MediaQuery.sizeOf(context).width / 375 +
                MediaQuery.paddingOf(context).bottom),
            child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 58,
                  child: context.englishLayout ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(themedAsset(context, 'assets/home/exact_masthead.png'),
                        fit: BoxFit.fill, excludeFromSemantics: true),
                      Semantics(label: context.tr('Document Scanner. Scan, Save, Share')),
                      Positioned(right: 8, top: 0, bottom: 0, width: 48,
                        child: Tooltip(message: context.tr('Search files'),
                          child: Semantics(button: true, label: context.tr('Search files'),
                            child: InkWell(onTap: busy ? null : () => browse(search: true))))),
                    ],
                  ) : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Image.asset('assets/home/brand.png', width: 39,
                          excludeFromSemantics: true),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('Document Scanner', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.w600)),
                          AppText('Scan • Save • Share', maxLines: 1,
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                        ])),
                      IconButton(tooltip: context.tr('Search files'),
                        onPressed: busy ? null : () => browse(search: true),
                        icon: const Icon(Icons.search, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: ColoredBox(
                    color: AppPalette.of(context).background,
                    child: AnimatedBuilder(
                      animation: store,
                      builder: (context, _) => CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Container(
                              color: AppPalette.of(context).surface,
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                16,
                                14,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionTitle('Scan Options'),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      for (final kind in ScanKind.values) ...[
                                        if (kind.index > 0)
                                          const SizedBox(width: 8),
                                        Expanded(
                                          child: CategoryTile(
                                            kind: kind,
                                            folder: false,
                                            onTap: busy
                                                ? null
                                                : () => scan(kind),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: AppPalette.of(context).surface),
                              child: Container(
                              decoration: BoxDecoration(color: AppPalette.of(context).background,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                15,
                                15,
                                21,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionTitle('My Documents'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      for (final kind in ScanKind.values) ...[
                                        if (kind.index > 0)
                                          const SizedBox(width: 8),
                                        Expanded(
                                          child: CategoryTile(
                                            kind: kind,
                                            folder: true,
                                            count: store.files
                                                .where((d) => d.kind == kind)
                                                .length,
                                            onTap: () => browse(kind: kind),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Container(
                              height: 39,
                              padding: const EdgeInsets.fromLTRB(15, 16, 5, 0),
                              decoration: BoxDecoration(
                                color: AppPalette.of(context).surface,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: SectionTitle('Recent Files'),
                                  ),
                                  if (store.files.isNotEmpty) TextButton(
                                    onPressed: () => browse(),
                                    child: AppText(
                                      'See all',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppPalette.of(context).primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (store.unreadableRecords > 0)
                            SliverToBoxAdapter(
                              child: Container(
                                color: AppPalette.of(context).surface,
                                padding: const EdgeInsets.all(15),
                                child: const AppText(
                                  'Some saved records could not be opened. Original files have been retained.',
                                ),
                              ),
                            ),
                          if (store.files.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: ColoredBox(
                                color: AppPalette.of(context).surface,
                                child: ScanEmptyState(),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => ColoredBox(
                                  color: AppPalette.of(context).surface,
                                  child: FileRow(
                                    document: store.files[i],
                                    onOpen: () =>
                                        run(() => open(store.files[i])),
                                    onAction: (a) =>
                                        fileAction(store.files[i], a),
                                  ),
                                ),
                                childCount: store.files.length > 8
                                    ? 8
                                    : store.files.length,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: ColoredBox(
                              color: AppPalette.of(context).surface,
                              child: SizedBox(height: 116),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          Positioned(left: 0, right: 0, bottom: 0,
            child: ReferenceHomeNavigation(
              cameraKey: cameraButtonKey,
              cameraVisible: !menuOpen,
              onScan: busy ? null : chooseScan,
              onHome: () => scrollController.animateTo(0,
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              onSettings: busy ? null : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(onScan: chooseScan))),
            ),
          ),
          if (busy && (ModalRoute.of(context)?.isCurrent ?? true))
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),

    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => AppText(
    text,
    style: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppPalette.of(context).text,
    ),
  );
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.kind,
    required this.folder,
    this.count = 0,
    this.onTap,
  });
  final ScanKind kind;
  final bool folder;
  final int count;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: folder
        ? context.tr('{type}, {count} files', {'type': context.tr(kind.label), 'count': count})
        : context.tr('Scan {type}', {'type': context.tr(kind.label)}),
    child: AspectRatio(
      aspectRatio: context.englishLayout ? (folder ? 83 / 93 : 82 / 94)
          : 83 / (112 + (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(0, 40) * 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            if (context.englishLayout) Ink.image(
              image: AssetImage(themedAsset(context, 'assets/home/exact_${folder ? 'tile' : 'scan'}_${kind.name}.png')),
              fit: BoxFit.fill,
            ) else ...[
              DecoratedBox(decoration: BoxDecoration(
                color: AppPalette.of(context).dark
                    ? AppPalette.of(context).selected : tileColors[kind.index],
                borderRadius: BorderRadius.circular(14))),
              Positioned(top: folder ? 12 : 10, left: 0, right: 0,
                child: Center(child: Image.asset(
                  'assets/home/${folder ? 'folder_' : ''}${kind.name}.png',
                  width: folder ? 40 : 36, height: 34,
                  excludeFromSemantics: true))),
              Positioned(left: 3, right: 3, top: folder ? 47 : 51,
                child: AppText(kind.label, textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, height: 1.2,
                    fontWeight: FontWeight.w600, color: AppPalette.of(context).text))),
            ],
            if (folder) Positioned(left: 0, right: 0, bottom: 10,
              child: AppText(count == 1 ? '{count} file' : '{count} files',
                arguments: {'count': count},
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 9, height: 1))),
          ]),
        ),
      ),
    ),
  );
}

String sizeLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';
String ageLabel(BuildContext context, DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return context.tr('Just now');
  if (diff.inHours < 1) return context.tr('{count} min ago', {'count': diff.inMinutes});
  if (diff.inDays < 1) return context.tr('{count} hr ago', {'count': diff.inHours});
  return context.tr(diff.inDays == 1 ? '{count} day ago' : '{count} days ago',
      {'count': diff.inDays});
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onAction,
    this.hideTextExtension = false,
    this.onSelect,
    this.selecting = false,
    this.selected = false,
  });
  final bool hideTextExtension, selecting, selected;
  final VoidCallback? onSelect;
  final ScanFile document;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.of(context).selected : Colors.transparent,
      child: InkWell(
      onTap: selecting ? onSelect : onOpen,
      onLongPress: onSelect,
      child: Padding(
        padding: const EdgeInsets.only(left: 14.5, right: 7),
        child: Row(
          children: [
            if (selecting) Semantics(
              label: context.tr('Select {filename}', {'filename': document.filename}),
              child: Checkbox(
                key: ValueKey('select-file-' + document.id),
                value: selected,
                shape: const CircleBorder(),
                activeColor: AppPalette.of(context).primary,
                onChanged: onSelect == null ? null : (_) => onSelect!(),
              ),
            ),
            FileThumbnail(extension: document.extension),
            const SizedBox(width: 13.222),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 60.986),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppPalette.of(context).outline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hideTextExtension && document.extension == 'txt'
                                  ? document.name
                                  : document.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppPalette.of(context).text, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            AppText(
                              '${hideTextExtension && document.extension == 'txt' ? '' : '${document.extension.toUpperCase()} • '}${sizeLabel(document.bytes)} • ${ageLabel(context, document.created)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.of(context).secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!selecting) PopupMenuButton<String>(
                      tooltip: context.tr('File options'),
                      padding: EdgeInsets.zero,
                      icon: const FileMoreIcon(),
                      color: AppPalette.of(context).surface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (action) {
                        if (action == 'Select') {
                          onSelect?.call();
                        } else {
                          onAction(action);
                        }
                      },
                      itemBuilder: (_) => [
                        for (final entry in {
                          'Open document actions': Icons.edit_document,
                          'Rename': Icons.edit_outlined,
                          'Download': Icons.file_download_outlined,
                          'Print': Icons.print_outlined,
                          'Share': Icons.share_outlined,
                          'Delete': Icons.delete_outline,
                          if (onSelect != null) 'Select': Icons.check_circle_outline,
                        }.entries)
                          PopupMenuItem(
                            value: entry.key,
                            height: 36,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  entry.value,
                                  size: 19,
                                  color: AppPalette.of(context).text,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: AppText(
                                    entry.key,
                                    style: TextStyle(
                                      color: AppPalette.of(context).text,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class EmptyFiles extends StatelessWidget {
  const EmptyFiles({super.key, this.search = false});
  final bool search;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ScanEmptyState(search: search),
    ),
  );
}

class FileBrowser extends StatefulWidget {
  const FileBrowser({
    super.key,
    required this.store,
    this.kind,
    required this.autofocus,
    required this.onOpen,
    required this.onAction,
    this.onScan,
  });
  final DocumentStore store;
  final VoidCallback? onScan;
  final ScanKind? kind;
  final bool autofocus;
  final Future<void> Function(ScanFile) onOpen;
  final FileAction onAction;
  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(widget.kind?.label ?? 'All Files')),
    bottomNavigationBar: ReferenceHomeNavigation(
      homeSelected: false,
      onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onScan: widget.onScan == null ? null : () => scanFromNavigation(context, widget.onScan),
      onSettings: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SettingsScreen(onScan: widget.onScan))),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 5, 15, 16),
          child: TextField(
            autofocus: widget.autofocus,
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: context.tr('Search files'),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final files = widget.store.files
                  .where(
                    (f) =>
                        (widget.kind == null || f.kind == widget.kind) &&
                        f.filename.toLowerCase().contains(
                          query.trim().toLowerCase(),
                        ),
                  )
                  .toList();
              if (files.isEmpty) return EmptyFiles(search: query.isNotEmpty);
              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, i) => FileRow(
                  document: files[i],
                  onOpen: () => widget.onOpen(files[i]),
                  onAction: (a) => widget.onAction(files[i], a),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// The See all destination includes files in every subfolder, newest first.
class RecentFilesScreen extends StatefulWidget {
  const RecentFilesScreen({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onAction,
    this.autofocus = false,
    this.onScan,
  });
  final DocumentStore store;
  final VoidCallback? onScan;
  final Future<void> Function(ScanFile) onOpen;
  final FileAction onAction;
  final bool autofocus;

  @override
  State<RecentFilesScreen> createState() => _RecentFilesScreenState();
}

class _RecentFilesScreenState extends State<RecentFilesScreen> {
  ScanKind? category;
  String query = '';
  late bool searching = widget.autofocus;
  bool busy = false, selecting = false;
  final selected = <String>{};

  List<ScanFile> get visibleFiles => widget.store.files.where((file) =>
      (category == null || file.kind == category) &&
      file.filename.toLowerCase().contains(query.trim().toLowerCase()))
      .toList()..sort((a, b) => b.created.compareTo(a.created));

  List<ScanFile> get chosen =>
      visibleFiles.where((file) => selected.contains(file.id)).toList();

  void notice(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(value)));
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      notice(error is FormatException
          ? error.message.toString()
          : 'Could not complete this action. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void clearSelection() {
    if (!mounted) return;
    setState(() {
      selecting = false;
      selected.clear();
    });
  }

  void toggle(String id) {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      selecting = true;
      if (!selected.add(id)) selected.remove(id);
    });
  }

  void changeCategory(ScanKind? kind) {
    if (busy) return;
    setState(() {
      category = kind;
      selected.clear();
    });
  }

  void changeQuery(String value) {
    if (busy) return;
    setState(() {
      query = value;
      selected.clear();
    });
  }

  Future<String?> nameDialog() async {
    var value = '';
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const AppText('PDF'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.tr('Enter File Name'),
              border: OutlineInputBorder(),
            ),
            onChanged: (text) => value = text,
            validator: (text) {
              try {
                DocumentStore.validateName(text ?? '');
                return null;
              } on FormatException catch (error) {
                return context.tr(error.message.toString());
              }
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const AppText('Cancel')),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, value.trim());
              }
            },
            child: const AppText('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> moveSelected() async {
    final files = chosen;
    if (busy || files.isEmpty || files.any((file) => file.kind != files.first.kind)) return;
    final kind = files.first.kind;
    final folders = DocumentFolders(widget.store, kind: kind);
    var loaded = false;
    await perform(() async {
      await folders.load();
      loaded = true;
    });
    if (!loaded || !mounted) return;
    final target = await showAppActionSheet<String>(
      context: context,
      title: const AppText('Move Files'),
      maxHeightFraction: .65,
      actions: (sheetContext) => [
        for (final id in ['', ...folders.names.keys])
          ListTile(
            key: ValueKey('recent-move-' + id),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: AppActionIcon('Move',
                color: AppPalette.of(sheetContext).text),
            title: Text(id.isEmpty ? context.tr(kind.label) : folders.names[id]!),
            trailing: files.every((file) =>
                folders.membership[file.id] == (id.isEmpty ? null : id))
                ? Icon(Icons.check_circle,
                    color: AppPalette.of(sheetContext).primary)
                : null,
            onTap: () => Navigator.pop(sheetContext, id),
          ),
      ],
    );
    if (target == null || !mounted) return;
    await perform(() async {
      await folders.move(files.map((file) => file.id), target.isEmpty ? null : target);
      clearSelection();
      notice('Selected files moved.');
    });
  }

  Future<void> shareSelected() async {
    final files = chosen;
    if (files.isEmpty) return;
    await perform(() async {
      final box = context.findRenderObject()! as RenderBox;
      await SharePlus.instance.share(ShareParams(
        files: files.map((file) => XFile(widget.store.fileFor(file).path)).toList(),
        fileNameOverrides: files.map((file) => file.filename).toList(),
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ));
    });
  }

  Future<void> deleteSelected() async {
    final files = chosen;
    if (busy || files.isEmpty) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const AppText('Delete Item', textAlign: TextAlign.center),
          content: AppText('Delete {count} selected files?', arguments: {'count': files.length}),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const AppText('Ok'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    await perform(() async {
      // Load category indexes before deleting, and clean their memberships too.
      final indexes = <ScanKind, DocumentFolders>{};
      for (final kind in files.map((file) => file.kind).toSet()) {
        final folders = DocumentFolders(widget.store, kind: kind);
        await folders.load();
        indexes[kind] = folders;
      }
      for (final file in files) {
        await widget.store.delete(file);
      }
      for (final entry in indexes.entries) {
        await entry.value.move(
          files.where((file) => file.kind == entry.key).map((file) => file.id),
          null,
        );
      }
      clearSelection();
    });
  }

  Future<void> mergeSelected() async {
    final files = chosen;
    if (busy || files.length < 2 ||
        files.any((file) => !['pdf', 'txt'].contains(file.extension))) return;
    final name = await nameDialog();
    if (name == null || !mounted) return;
    await perform(() async {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
      const limit = 100;
      void checkPageLimit() {
        if (pdf.document.pdfPageList.pages.length > limit) {
          throw const FormatException('Merge supports up to 100 pages at a time.');
        }
      }
      for (final file in files) {
        if (file.extension == 'txt') {
          final text = await widget.store.fileFor(file).readAsString();
          final chunks = <String>[];
          var remaining = text;
          while (remaining.length > 700) {
            var end = remaining.lastIndexOf(' ', 700);
            if (end < 1) end = 700;
            chunks.add(remaining.substring(0, end));
            remaining = remaining.substring(end).trimLeft();
          }
          if (remaining.isNotEmpty) chunks.add(remaining);
          pdf.addPage(pw.MultiPage(
            maxPages: limit,
            build: (_) => [
              pw.Header(level: 1, text: file.name),
              for (final chunk in chunks) pw.Paragraph(text: chunk),
            ],
          ));
          checkPageLimit();
        } else {
          await for (final page in Printing.raster(
            await widget.store.fileFor(file).readAsBytes(), dpi: 144,
          )) {
            if (pdf.document.pdfPageList.pages.length >= limit) {
              throw const FormatException('Merge supports up to 100 pages at a time.');
            }
            final image = pw.MemoryImage(await page.toPng());
            pdf.addPage(pw.Page(
              pageFormat: PdfPageFormat(page.width * .5, page.height * .5),
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            ));
          }
        }
      }
      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw const FormatException('These files contain no readable pages.');
      }
      final kind = files.every((file) => file.kind == files.first.kind)
          ? files.first.kind : ScanKind.document;
      await widget.store.addBytes(await pdf.save(), kind, 'pdf', name: name);
      clearSelection();
      notice('Merged PDF saved. Original files retained.');
    });
  }

  Widget categoryFilter(ScanKind? kind) => Semantics(
    selected: category == kind, button: true,
    child: TextButton(
      key: ValueKey('recent-filter-' + (kind?.name ?? 'all')),
      onPressed: busy ? null : () => changeCategory(kind),
      style: TextButton.styleFrom(
        backgroundColor: category == kind
            ? AppPalette.of(context).primary : AppPalette.of(context).surface,
        foregroundColor: category == kind
            ? AppPalette.of(context).onPrimary : AppPalette.of(context).text,
        minimumSize: const Size(0, 32),
        padding: EdgeInsets.symmetric(horizontal: context.englishLayout ? 3 : 12),
        shape: const StadiumBorder(),
        side: BorderSide(color: category == kind
            ? Colors.transparent : AppPalette.of(context).outline),
      ),
      child: AppText(kind?.label ?? 'All', maxLines: 1,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    ),
  );

  Widget selectionTool(String label, IconData icon, VoidCallback? action,
      {String? hint}) => Expanded(
    child: AppToolbarAction(
      buttonKey: ValueKey('recent-action-' + label.toLowerCase()),
      label: label,
      icon: icon,
      hint: hint,
      primary: true,
      onPressed: busy ? null : action,
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final files = visibleFiles;
      // Removed or filtered-out files must never remain in a bulk operation.
      selected.retainAll(files.map((file) => file.id).toSet());
      final selectedFiles = files.where((file) => selected.contains(file.id)).toList();
      final count = selectedFiles.length;
      final all = files.isNotEmpty && count == files.length;
      final sameKind = count > 0 &&
          selectedFiles.every((file) => file.kind == selectedFiles.first.kind);
      final canMerge = count > 1 &&
          selectedFiles.every((file) => ['pdf', 'txt'].contains(file.extension));
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppPalette.of(context).surface,
          systemNavigationBarIconBrightness: AppPalette.of(context).dark ? Brightness.light : Brightness.dark,
        ),
        child: PopScope(
          canPop: !selecting && !busy,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !busy && selecting) clearSelection();
          },
          child: Scaffold(
            backgroundColor: AppPalette.of(context).surface,
            appBar: AppBar(
              backgroundColor: AppPalette.of(context).header,
              foregroundColor: Colors.white,
              systemOverlayStyle: AppPalette.of(context).systemBars,
              elevation: 0,
              titleSpacing: 0,
              leading: selecting ? IconButton(
                tooltip: context.tr('Cancel selection'),
                onPressed: busy ? null : clearSelection,
                icon: const Icon(Icons.close),
              ) : null,
              title: AppText(
                selecting ? (count == 0 ? 'Select items' : '{count} Selected') : 'Recent Files',
                arguments: {'count': count},
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              actions: selecting ? [
                TextButton(
                  onPressed: busy || files.isEmpty ? null : () => setState(() {
                    selected.clear();
                    if (!all) selected.addAll(files.map((file) => file.id));
                  }),
                  child: AppText(all ? 'Deselect all' : 'Select all',
                    style: const TextStyle(color: Colors.white)),
                ),
              ] : [
                IconButton(
                  tooltip: context.tr('Select files'),
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: busy || files.isEmpty ? null
                      : () => setState(() => selecting = true),
                ),
                IconButton(
                  tooltip: context.tr(searching ? 'Close search' : 'Search recent files'),
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: busy ? null : () => setState(() {
                    searching = !searching;
                    query = '';
                    selected.clear();
                  }),
                ),
              ],
            ),
            bottomNavigationBar: selecting ? ReferenceToolbarSurface(
              child: SafeArea(
                top: false,
                child: Row(children: [
                  selectionTool('Move', Icons.folder_outlined, sameKind ? moveSelected : null,
                    hint: count > 0 && !sameKind
                        ? 'Select files from one category to move' : 'Move'),
                  selectionTool('Share', Icons.share_outlined, count > 0 ? shareSelected : null),
                  selectionTool('Merge', Icons.copy_outlined, canMerge ? mergeSelected : null),
                  selectionTool('Delete', Icons.delete_outline, count > 0 ? deleteSelected : null),
                ]),
              ),
            ) : ReferenceHomeNavigation(
              homeSelected: false,
              onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
              onScan: widget.onScan == null ? null
                  : () => scanFromNavigation(context, widget.onScan),
              onSettings: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(onScan: widget.onScan))),
            ),
            body: ColoredBox(
              color: AppPalette.of(context).header,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: ColoredBox(
                  color: AppPalette.of(context).background,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
                      child: context.englishLayout
                          ? Row(children: [
                              for (final kind in <ScanKind?>[null, ...ScanKind.values]) ...[
                                if (kind != null) const SizedBox(width: 5),
                                Expanded(child: categoryFilter(kind)),
                              ],
                            ])
                          : SingleChildScrollView(scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                for (final kind in <ScanKind?>[null, ...ScanKind.values])
                                  Padding(padding: const EdgeInsetsDirectional.only(end: 6),
                                    child: categoryFilter(kind)),
                              ])),
                    ),
                    if (searching) Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                      child: TextField(
                        autofocus: true,
                        enabled: !busy,
                        onChanged: changeQuery,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: context.tr('Search recent files'),
                          filled: true,
                          fillColor: AppPalette.of(context).surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                    ),
                    if (busy && (ModalRoute.of(context)?.isCurrent ?? true))
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(child: files.isEmpty
                        ? EmptyFiles(search: query.trim().isNotEmpty)
                        : AbsorbPointer(
                            absorbing: busy,
                            child: ListView.builder(
                              key: ValueKey(category),
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: files.length,
                              itemBuilder: (_, index) {
                                final file = files[index];
                                return FileRow(
                                  key: ValueKey(file.id),
                                  document: file,
                                  hideTextExtension: true,
                                  selecting: selecting,
                                  selected: selected.contains(file.id),
                                  onSelect: () => toggle(file.id),
                                  onOpen: () => perform(() => widget.onOpen(file)),
                                  onAction: (action) => perform(
                                    () => widget.onAction(file, action)),
                                );
                              },
                            ),
                          )),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class DocumentPreview extends StatefulWidget {
  const DocumentPreview({
    super.key,
    required this.document,
    required this.file,
    this.onOptions,
    this.store,
  });
  final ScanFile document;
  final File file;
  final Future<void> Function()? onOptions;
  final DocumentStore? store;
  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  late ScanFile document = widget.document;
  int revision = 0;
  File get file => widget.file;

  Future<void> options() async {
    await widget.onOptions?.call();
    if (!mounted) return;
    setState(() {
      document = widget.store?.files.firstWhere(
        (file) => file.id == document.id,
        orElse: () => document,
      ) ?? document;
      revision++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(document.filename, overflow: TextOverflow.ellipsis),
      actions: [
        if (widget.onOptions != null)
          TextButton(onPressed: options, child: const AppText('Option')),
      ],
    ),
    body: document.extension == 'pdf'
        ? PdfPreview(
            useActions: false,
            key: ValueKey(revision),
            build: (_) => file.readAsBytes(),
            pdfFileName: document.filename,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          )
        : FutureBuilder<String>(
            future: file.readAsString(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: AppText('Could not read this file.'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      document.kind.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    SelectableText(snapshot.data!),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: snapshot.data!),
                        );
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: AppText('Copied to clipboard'),
                            ),
                          );
                      },
                      icon: const Icon(Icons.copy),
                      label: const AppText('Copy content'),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
