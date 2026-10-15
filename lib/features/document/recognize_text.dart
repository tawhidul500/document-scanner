import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/document_store.dart';

Future<String> recognizeDocumentText(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.blocks.map((block) => block.text).join('\n\n').trim();
  } finally {
    await recognizer.close();
  }
}

/// A separate text PDF keeps the source scan intact.
Future<Uint8List> buildRecognizedTextPdf(String text, ByteData fontData) async {
  final pdf = pw.Document();
  final font = pw.Font.ttf(fontData);
  // Small text chunks allow long OCR results to paginate without an oversized
  // unbreakable paragraph. Whitespace remains meaningful between paragraphs.
  final paragraphs = <String>[];
  for (final paragraph in text.split(RegExp(r'\n\s*\n'))) {
    var remainder = paragraph.trim();
    while (remainder.length > 700) {
      var split = remainder.lastIndexOf(' ', 700);
      if (split < 1) split = 700;
      paragraphs.add(remainder.substring(0, split));
      remainder = remainder.substring(split).trimLeft();
    }
    if (remainder.isNotEmpty) paragraphs.add(remainder);
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      maxPages: 1000,
      theme: pw.ThemeData.withFont(base: font),
      build: (_) => [
        for (final paragraph in paragraphs)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              paragraph,
              textAlign: pw.TextAlign.justify,
              style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 3),
            ),
          ),
      ],
    ),
  );
  return pdf.save();
}

class RecognizeTextScreen extends StatefulWidget {
  const RecognizeTextScreen({
    super.key,
    required this.path,
    required this.store,
    this.recognize = recognizeDocumentText,
  });
  final String path;
  final DocumentStore store;
  final Future<String> Function(String) recognize;

  @override
  State<RecognizeTextScreen> createState() => _RecognizeTextScreenState();
}

class _RecognizeTextScreenState extends State<RecognizeTextScreen> {
  final text = TextEditingController();
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    recognize();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> recognize() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.recognize(widget.path);
      if (!mounted) return;
      setState(() {
        text.text = value;
        if (value.isEmpty)
          error = 'No text found. Try a clearer, well-lit scan.';
      });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not recognize text. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (loading || saving || text.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PdfNameDialog(),
    );
    if (name == null || !mounted) return;
    setState(() => saving = true);
    try {
      final font = await rootBundle.load('assets/fonts/Inter.ttf');
      final bytes = await buildRecognizedTextPdf(text.text.trim(), font);
      final document = await widget.store.addBytes(
        bytes,
        ScanKind.document,
        'pdf',
        name: name,
      );
      if (mounted) Navigator.pop(context, document);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save PDF. Check available storage and retry.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Recognize Text',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: loading || saving || text.text.trim().isEmpty
                ? null
                : save,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5262FF),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBEBEB), Color(0xFFEBEBEB), Colors.white],
            stops: [0, .86, 1],
          ),
        ),
        child: Column(
          children: [
            if (saving) const LinearProgressIndicator(),
            if (loading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Recognizing text…'),
                    ],
                  ),
                ),
              )
            else ...[
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: recognize,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: text,
                  readOnly: saving,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF303030),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 26, 14, 20),
                    hintText: 'Recognized text will appear here.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PdfNameDialog extends StatefulWidget {
  const _PdfNameDialog();
  @override
  State<_PdfNameDialog> createState() => _PdfNameDialogState();
}

class _PdfNameDialogState extends State<_PdfNameDialog> {
  final name = TextEditingController();
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void submit() {
    try {
      final value = name.text.trim().replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      Navigator.pop(context, DocumentStore.validateName(value));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: const Text(
      'PDF',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    ),
    content: SizedBox(
      width: 220,
      child: TextField(
        controller: name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => submit(),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Enter File Name',
          errorText: error,
          errorMaxLines: 2,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF5262FF), width: 2),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: submit, child: const Text('Ok')),
    ],
    actionsPadding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
  );
}
