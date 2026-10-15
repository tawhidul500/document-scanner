import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'editor_processing.dart';

const editorAccent = Color(0xFF5262FF);
const editorBackground = Color(0xFFEBEBEB);

class PageEditResult {
  const PageEditResult(this.bytes, this.paperSize);
  final Uint8List bytes;
  final String paperSize;
}

enum EditorTool { filter, resize, rotate }

const filterNames = [
  'No Filter',
  'AddictiveBlue',
  'AddictiveRed',
  'Aden',
  'Amaro',
];
const paperNames = ['Original Size', 'A4 Size', 'A5 Size', 'ID Card', 'Legal'];
const paperKeys = ['original', 'a4', 'a5', 'id', 'legal'];

class EditorToolScreen extends StatefulWidget {
  const EditorToolScreen({
    super.key,
    required this.tool,
    required this.bytes,
    required this.name,
    required this.paperSize,
  });
  final EditorTool tool;
  final Uint8List bytes;
  final String name, paperSize;
  @override
  State<EditorToolScreen> createState() => _EditorToolScreenState();
}

class _EditorToolScreenState extends State<EditorToolScreen> {
  int preset = 0, turns = 0;
  double strength = .4;
  late String paperSize = widget.paperSize;
  bool busy = false;
  String? error;

  Future<void> done() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = widget.tool == EditorTool.resize
          ? widget.bytes
          : await compute(applyEditorTool, <String, Object>{
              'bytes': widget.bytes,
              'tool': widget.tool.name,
              'preset': preset,
              'strength': strength,
              'turns': turns,
            });
      if (mounted) Navigator.pop(context, PageEditResult(result, paperSize));
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not apply this edit. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: editorBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: widget.tool != EditorTool.rotate,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          switch (widget.tool) {
            EditorTool.filter => 'Filter',
            EditorTool.resize => 'Resize',
            EditorTool.rotate => widget.name,
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : done,
            child: const Text(
              'Done',
              style: TextStyle(color: editorAccent, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
          Expanded(
            child: DocumentImagePreview(
              bytes: widget.bytes,
              paperSize: widget.tool == EditorTool.resize
                  ? paperSize
                  : widget.paperSize,
              quarterTurns: turns,
              matrix: widget.tool == EditorTool.filter
                  ? documentFilterMatrix(preset, strength)
                  : null,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: IgnorePointer(
            ignoring: busy,
            child: switch (widget.tool) {
              EditorTool.filter => filters(),
              EditorTool.resize => sizes(),
              EditorTool.rotate => rotations(),
            },
          ),
        ),
      ),
    ),
  );

  Widget filters() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 200,
        height: 32,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: strength,
            activeColor: editorAccent,
            inactiveColor: const Color(0xFFEDEDED),
            label: '${(strength * 100).round()}%',
            onChanged: (value) => setState(() => strength = value),
          ),
        ),
      ),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: filterNames.length,
          separatorBuilder: (_, index) => const SizedBox(width: 16),
          itemBuilder: (context, i) => Semantics(
            selected: preset == i,
            button: true,
            label: filterNames[i],
            child: InkWell(
              onTap: () => setState(() => preset = i),
              child: SizedBox(
                width: 60,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 58,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: preset == i
                              ? editorAccent
                              : const Color(0xFFE0E0E0),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 5),
                        ],
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          documentFilterMatrix(i, 1),
                        ),
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      filterNames[i],
                      style: const TextStyle(fontSize: 9),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget sizes() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: List.generate(
        paperKeys.length,
        (i) => Expanded(
          child: TextButton(
            onPressed: () => setState(() => paperSize = paperKeys[i]),
            style: TextButton.styleFrom(
              foregroundColor: paperSize == paperKeys[i]
                  ? const Color(0xFF0066FF)
                  : const Color(0xFF555555),
              padding: const EdgeInsets.symmetric(horizontal: 1),
              minimumSize: const Size(0, 48),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 23),
                const SizedBox(height: 5),
                Text(paperNames[i], style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget rotations() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 48),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final item in [
          (Icons.rotate_left, 'Rotate Left', -1),
          (Icons.rotate_right, 'Rotate Right', 1),
        ])
          TextButton(
            onPressed: () => setState(() => turns = (turns + item.$3) % 4),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF555555),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 27),
                const SizedBox(height: 4),
                Text(item.$2, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    ),
  );
}

class DocumentImagePreview extends StatelessWidget {
  const DocumentImagePreview({
    super.key,
    required this.bytes,
    this.paperSize = 'original',
    this.quarterTurns = 0,
    this.matrix,
  });
  final Uint8List bytes;
  final String paperSize;
  final int quarterTurns;
  final List<double>? matrix;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.memory(
      bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (matrix != null)
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix!),
        child: image,
      );
    if (quarterTurns != 0)
      image = RotatedBox(quarterTurns: quarterTurns, child: image);
    if (paperSize != 'original') {
      final size = documentPaperSize(paperSize, 1, 1);
      image = AspectRatio(
        aspectRatio: size[0] / size[1],
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: image),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 35, 28, 16),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Align(alignment: Alignment.topCenter, child: image),
      ),
    );
  }
}
