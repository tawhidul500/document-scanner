import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/document_store.dart';
import '../scan/code_scanner.dart';
import '../settings/settings_screen.dart';
import '../folders/document_folder_screen.dart';
import 'camera_action_menu.dart';
import '../document/document_camera.dart';
import '../document/document_review.dart';
import '../document/id_card_preview.dart';
import '../document/id_card_processing.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      message(
        'Could not complete this action. Check camera access or available storage and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan(ScanKind kind) => run(() async {
    if (kind == ScanKind.document || kind == ScanKind.idCard) {
      final cache = await getTemporaryDirectory();
      final session = await Directory(
        '${cache.path}/document_session_',
      ).createTemp();
      try {
        if (!mounted) return;
        final pages = await Navigator.of(context).push<List<String>>(
          MaterialPageRoute(
            builder: (_) => DocumentCamera(
              directory: session,
              idCard: kind == ScanKind.idCard,
            ),
          ),
        );
        if (pages == null || pages.isEmpty || !mounted) return;
        final bytes = kind == ScanKind.idCard
            ? await compute(buildIdCardPdf, pages)
            : await compute(buildPdfFromPaths, pages);
        final doc = await store.addBytes(bytes, kind, 'pdf');
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => kind == ScanKind.idCard
                ? IdCardPreview(store: store, document: doc)
                : DocumentReview(
                    pages: pages,
                    directory: session,
                    store: store,
                    document: doc,
                  ),
          ),
        );
      } finally {
        try {
          await session.delete(recursive: true);
        } catch (_) {}
      }
      return;
    }
    late final ScanFile saved;
    if (kind == ScanKind.qr || kind == ScanKind.barcode) {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => CodeScanner(qrOnly: kind == ScanKind.qr),
        ),
      );
      if (!mounted || result == null) return;
      saved = await store.addBytes(utf8.encode(result), kind, 'txt');
    } else {
      return;
    }
    if (mounted) await open(saved);
  });

  Future<void> chooseScan() async {
    if (busy || menuOpen) return;
    final box =
        cameraButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    menuOpen = true;
    CameraAction? action;
    try {
      action = await showCameraActionMenu(context, anchor);
    } finally {
      menuOpen = false;
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
      if (mounted) await open(doc);
    } on FormatException catch (e) {
      message(e.message);
    }
  });

  Future<void> open(ScanFile doc) async {
    if (!await store.fileFor(doc).exists()) {
      message('This file is no longer available.');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => doc.kind == ScanKind.idCard
            ? IdCardPreview(store: store, document: doc)
            : DocumentPreview(document: doc, file: store.fileFor(doc)),
      ),
    );
  }

  Future<void> reviewForSharing(ScanFile doc) async {
    final cache = await getTemporaryDirectory();
    final session = await Directory(
      '${cache.path}/document_review_',
    ).createTemp();
    try {
      final pages = <String>[];
      final file = store.fileFor(doc);
      if (doc.filename.toLowerCase().endsWith('.pdf')) {
        await for (final page in Printing.raster(
          await file.readAsBytes(),
          dpi: 144,
        )) {
          if (pages.length >= 50) {
            throw const FormatException(
              'Document exceeds the 50-page editing limit.',
            );
          }
          final image = File('${session.path}/page_${pages.length}.png');
          await image.writeAsBytes(await page.toPng(), flush: true);
          pages.add(image.path);
        }
      } else {
        // Other file kinds retain their existing native sharing behavior.
        if (!mounted) return;
        final box = context.findRenderObject()! as RenderBox;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            fileNameOverrides: [doc.filename],
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          ),
        );
        return;
      }
      if (pages.isEmpty || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentReview(
            pages: pages,
            directory: session,
            store: store,
            document: doc,
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
          title: const Text('Rename file'),
          content: Form(
            key: form,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'File name',
                suffixText: '.${doc.extension}',
              ),
              validator: (v) {
                try {
                  DocumentStore.validateName(v ?? '');
                  return null;
                } on FormatException catch (e) {
                  return e.message;
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate())
                  Navigator.pop(c, controller.text);
              },
              child: const Text('Save'),
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
          title: const Text('Delete file?'),
          content: Text(
            'Delete ${doc.filename} from this app? Exported copies will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (yes == true && mounted) await run(() => store.delete(doc));
    } else {
      await run(() async {
        final file = store.fileFor(doc);
        if (action == 'Download') {
          final saved = await FlutterFileDialog.saveFile(
            params: SaveFileDialogParams(
              sourceFilePath: file.path,
              fileName: doc.filename,
            ),
          );
          if (saved != null) message('File exported successfully.');
        } else if (action == 'Share') {
          await reviewForSharing(doc);
        }
      });
    }
  }

  void browse({ScanKind? kind, bool search = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => kind != null
            ? DocumentFolderScreen(
                store: store,
                kind: kind,
                onOpen: open,
                onAction: fileAction,
              )
            : RecentFilesScreen(
                store: store,
                autofocus: search,
                onOpen: open,
                onAction: fileAction,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: blue,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 10, 10),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/home/brand.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          label: 'Document Scanner. Scan, Save, Share',
                          image: false,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/home/header.png',
                              width: 235,
                              height: 40,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => browse(search: true),
                        tooltip: 'Search files',
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: ColoredBox(
                    color: pale,
                    child: AnimatedBuilder(
                      animation: store,
                      builder: (context, _) => CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                16,
                                14,
                                19,
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
                            child: Padding(
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
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(15, 10, 5, 0),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: SectionTitle('Recent Files'),
                                  ),
                                  TextButton(
                                    onPressed: () => browse(),
                                    child: const Text(
                                      'See all',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1457C6),
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
                                color: Colors.white,
                                padding: const EdgeInsets.all(15),
                                child: const Text(
                                  'Some saved records could not be opened. Original files have been retained.',
                                ),
                              ),
                            ),
                          if (store.files.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: ColoredBox(
                                color: Colors.white,
                                child: EmptyFiles(),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => ColoredBox(
                                  color: Colors.white,
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
                          const SliverToBoxAdapter(
                            child: ColoredBox(
                              color: Colors.white,
                              child: SizedBox(height: 30),
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
          if (busy)
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        key: cameraButtonKey,
        width: 64,
        height: 64,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 3,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: FloatingActionButton(
            onPressed: busy ? null : chooseScan,
            tooltip: 'Scan',
            elevation: 0,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.camera_alt_rounded, size: 27),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_rounded, color: accent, size: 25),
                        SizedBox(height: 4),
                        Text(
                          'Home',
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 120),
                Expanded(
                  child: InkWell(
                    onTap: busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: Colors.black,
                          size: 25,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Settings',
                          style: TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: ink,
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
    label: folder ? '${kind.label}, $count files' : 'Scan ${kind.label}',
    child: Material(
      color: folder ? Colors.white : tileColors[kind.index],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(3, folder ? 8 : 12, 3, folder ? 9 : 14),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Image.asset(
                  'assets/home/${folder ? 'folder_' : ''}${kind.name}.png',
                  height: folder ? 38 : 42,
                  width: folder ? 48 : 42,
                ),
                SizedBox(height: folder ? 7 : 10),
                Text(
                  kind.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (folder) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$count ${count == 1 ? 'file' : 'files'}',
                    style: const TextStyle(color: muted, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String sizeLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';
String ageLabel(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onAction,
    this.hideTextExtension = false,
  });
  final bool hideTextExtension;
  final ScanFile document;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final pdf = document.extension == 'pdf';
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 7),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 46,
              decoration: BoxDecoration(
                color: pdf ? const Color(0xFFFFF1F2) : Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                pdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.text_snippet_outlined,
                color: pdf ? const Color(0xFFFF3F50) : const Color(0xFF394D9D),
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 61),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line)),
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
                              style: const TextStyle(color: ink, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${hideTextExtension && document.extension == 'txt' ? '' : '${document.extension.toUpperCase()} • '}${sizeLabel(document.bytes)} • ${ageLabel(document.created)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'File options',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF44536B),
                        size: 22,
                      ),
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        for (final entry in {
                          'Rename': Icons.edit_outlined,
                          'Download': Icons.file_download_outlined,
                          'Share': Icons.share_outlined,
                          'Delete': Icons.delete_outline,
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
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
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
    );
  }
}

class EmptyFiles extends StatelessWidget {
  const EmptyFiles({super.key, this.search = false});
  final bool search;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          search ? Icons.search_off : Icons.folder_open_rounded,
          size: 45,
          color: muted,
        ),
        const SizedBox(height: 12),
        Text(
          search ? 'No matching files' : 'No scans yet',
          style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        ),
        const SizedBox(height: 6),
        Text(
          search
              ? 'Try another file name.'
              : 'Tap a scan option or the camera to save your first file.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 13),
        ),
      ],
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
  });
  final DocumentStore store;
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
    appBar: AppBar(title: Text(widget.kind?.label ?? 'All Files')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 5, 15, 16),
          child: TextField(
            autofocus: widget.autofocus,
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search files',
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
  });
  final DocumentStore store;
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
  bool busy = false;

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open or update this file. Please try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF205BC3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF205BC3),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Recent Files',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: searching ? 'Close search' : 'Search recent files',
            icon: Icon(searching ? Icons.close : Icons.search),
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
          color: const Color(0xFFF4F7FD),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
                child: Row(
                  children: [
                    for (final kind in <ScanKind?>[
                      null,
                      ...ScanKind.values,
                    ]) ...[
                      if (kind != null) const SizedBox(width: 5),
                      Expanded(
                        child: Semantics(
                          selected: category == kind,
                          button: true,
                          child: TextButton(
                            key: ValueKey(
                              'recent-filter-${kind?.name ?? 'all'}',
                            ),
                            onPressed: () => setState(() => category = kind),
                            style: TextButton.styleFrom(
                              backgroundColor: category == kind
                                  ? const Color(0xFF205BC3)
                                  : Colors.white,
                              foregroundColor: category == kind
                                  ? Colors.white
                                  : ink,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: category == kind
                                    ? Colors.transparent
                                    : line,
                              ),
                            ),
                            child: Text(
                              kind?.label ?? 'All',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search recent files',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
              if (busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.store,
                  builder: (context, _) {
                    final files =
                        widget.store.files
                            .where(
                              (file) =>
                                  (category == null || file.kind == category) &&
                                  file.filename.toLowerCase().contains(
                                    query.trim().toLowerCase(),
                                  ),
                            )
                            .toList()
                          ..sort((a, b) => b.created.compareTo(a.created));
                    if (files.isEmpty)
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            query.trim().isNotEmpty
                                ? 'No matching files'
                                : category == null
                                ? 'No recent files yet'
                                : 'No ${category!.label.toLowerCase()} files yet',
                            style: const TextStyle(color: muted),
                          ),
                        ),
                      );
                    return AbsorbPointer(
                      absorbing: busy,
                      child: ListView.builder(
                        key: ValueKey(category),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: files.length,
                        itemBuilder: (_, index) => FileRow(
                          key: ValueKey(files[index].id),
                          document: files[index],
                          hideTextExtension: true,
                          onOpen: () =>
                              perform(() => widget.onOpen(files[index])),
                          onAction: (action) => perform(
                            () => widget.onAction(files[index], action),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DocumentPreview extends StatelessWidget {
  const DocumentPreview({
    super.key,
    required this.document,
    required this.file,
  });
  final ScanFile document;
  final File file;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(document.filename, overflow: TextOverflow.ellipsis),
    ),
    body: document.extension == 'pdf'
        ? PdfPreview(
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
                return const Center(child: Text('Could not read this file.'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                              content: Text('Copied to clipboard'),
                            ),
                          );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy content'),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
