import '../../widgets/app_toolbar_action.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import '../../widgets/reference_toolbar_surface.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const signatureColors = <Color>[
  Colors.black,
  Colors.white,
  Color(0xFFC7C7C7),
  Color(0xFFFF252D),
  Color(0xFF81FF00),
  Color(0xFF2464FF),
  Color(0xFFE500F5),
  Color(0xFFFFC832),
  Color(0xFF8558FF),
];

class SignatureInk {
  const SignatureInk(this.strokes, this.color, this.weight);
  final List<List<Offset>> strokes;
  final Color color;
  final double weight;

  Rect bounds(double weight) {
    final points = strokes.expand((stroke) => stroke).toList();
    if (points.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(weight / 10 + 3);
  }
}

void paintInk(
  Canvas canvas,
  List<List<Offset>> strokes,
  Color color,
  double weight,
) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = weight / 10
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, weight / 20, Paint()..color = color);
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (final point in stroke.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

class SignatureStyleBar extends StatelessWidget {
  const SignatureStyleBar({
    super.key,
    required this.color,
    required this.weight,
    required this.onColor,
    required this.onWeight,
    this.gallery = false,
  });
  final Color color;
  final double weight;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWeight;
  final bool gallery;

  @override
  Widget build(BuildContext context) => ReferenceToolbarSurface(
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: AppPalette.of(context).secondary,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Slider(
                      value: weight,
                      min: 1,
                      max: 70,
                      activeColor: AppPalette.of(context).primary,
                      inactiveColor: AppPalette.of(context).outline,
                      label: gallery
                          ? context.tr('{percent}% opacity', {'percent': (weight / 70 * 100).round()})
                          : '${weight.round()}',
                      onChanged: onWeight,
                    ),
                  ),
                  AppText(
                    gallery
                        ? '${(weight / 70 * 100).round()}%'
                        : '${weight.round()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: signatureColors.length,
                separatorBuilder: (_, index) => const SizedBox(width: 9),
                itemBuilder: (context, i) => Semantics(
                  button: true,
                  selected: signatureColors[i] == color,
                  label: context.tr('Signature color {number}', {'number': i + 1}),
                  child: InkWell(
                    onTap: () => onColor(signatureColors[i]),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 2,
                          color: signatureColors[i] == color
                              ? AppPalette.of(context).primary
                              : Colors.transparent,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: signatureColors[i],
                          border: Border.all(color: AppPalette.of(context).controlOutline),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SignatureDrawScreen extends StatefulWidget {
  const SignatureDrawScreen({super.key});
  @override
  State<SignatureDrawScreen> createState() => _SignatureDrawScreenState();
}

class _SignatureDrawScreenState extends State<SignatureDrawScreen> {
  final strokes = <List<Offset>>[], redo = <List<Offset>>[];
  Color color = const Color(0xFF2464FF);
  double weight = 30;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.of(context).workspace,
    appBar: AppBar(
      backgroundColor: AppPalette.of(context).surface,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: context.tr('Undo stroke'),
          onPressed: strokes.isEmpty
              ? null
              : () => setState(() => redo.add(strokes.removeLast())),
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: context.tr('Redo stroke'),
          onPressed: redo.isEmpty
              ? null
              : () => setState(() => strokes.add(redo.removeLast())),
          icon: const Icon(Icons.redo),
        ),
        const SizedBox(width: 22),
        IconButton(
          tooltip: context.tr('Use signature'),
          onPressed: strokes.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  SignatureInk(
                    strokes.map((s) => List<Offset>.of(s)).toList(),
                    color,
                    weight,
                  ),
                ),
          style: IconButton.styleFrom(
            foregroundColor: AppPalette.of(context).primary,
            disabledForegroundColor: AppPalette.of(context).disabled),
          icon: const Icon(Icons.check),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, box) {
        Offset point(Offset p) => Offset(
          p.dx.clamp(0.0, box.maxWidth).toDouble(),
          p.dy.clamp(0.0, box.maxHeight).toDouble(),
        );
        return ColoredBox(color: const Color(0xFFEBEBEB), child: GestureDetector(
          key: const ValueKey('signature-canvas'),
          behavior: HitTestBehavior.opaque,
          // Begin the stroke where the finger lands, not after the pan slop.
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (event) => setState(() {
            redo.clear();
            strokes.add([point(event.localPosition)]);
          }),
          onPanUpdate: (event) => setState(() {
            if (strokes.isNotEmpty)
              strokes.last.add(point(event.localPosition));
          }),
          onTapUp: (event) => setState(() {
            redo.clear();
            strokes.add([point(event.localPosition)]);
          }),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (strokes.isEmpty)
                const Align(
                  alignment: Alignment(0, -.3),
                  child: AppText(
                    'Sign here',
                    style: TextStyle(fontSize: 18, color: Color(0xFF566781)),
                  ),
                ),
              CustomPaint(painter: _InkPainter(strokes, color, weight)),
            ],
          ),
        ));
      },
    ),
    bottomNavigationBar: SignatureStyleBar(
      color: color,
      weight: weight,
      onColor: (value) => setState(() => color = value),
      onWeight: (value) => setState(() => weight = value),
    ),
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.color, this.weight);
  final List<List<Offset>> strokes;
  final Color color;
  final double weight;
  @override
  void paint(Canvas canvas, Size size) =>
      paintInk(canvas, strokes, color, weight);
  @override
  bool shouldRepaint(_InkPainter oldDelegate) => true;
}

class SignatureEditor extends StatefulWidget {
  const SignatureEditor({super.key, required this.path});
  final String path;
  @override
  State<SignatureEditor> createState() => _SignatureEditorState();
}

class _SignatureEditorState extends State<SignatureEditor> {
  ui.Image? page, gallery;
  SignatureInk? ink;
  Color color = const Color(0xFF2464FF);
  double weight = 30, scale = 1, rotation = 0;
  Offset center = const Offset(.5, .65);
  double startScale = 1, startRotation = 0;
  Offset startCenter = Offset.zero, startFocal = Offset.zero;
  bool busy = true, tintGallery = false;
  String? error;
  bool get hasSignature => ink != null || gallery != null;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    page?.dispose();
    gallery?.dispose();
    super.dispose();
  }

  Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> load() async {
    try {
      final image = await decode(await File(widget.path).readAsBytes());
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        page = image;
        error = null;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not open this page.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> draw() async {
    final result = await Navigator.of(context).push<SignatureInk>(
      MaterialPageRoute(builder: (_) => const SignatureDrawScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      gallery?.dispose();
      gallery = null;
      ink = result;
      color = result.color;
      weight = result.weight;
      scale = 1;
      rotation = 0;
      center = const Offset(.5, .65);
      error = null;
      if (page != null)
        clampPlacement(Size(page!.width.toDouble(), page!.height.toDouble()));
    });
  }

  Future<void> importSignature() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selected == null) return;
      final image = await decode(await selected.readAsBytes());
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        gallery?.dispose();
        gallery = image;
        ink = null;
        tintGallery = false;
        weight = 70;
        scale = 1;
        rotation = 0;
        center = const Offset(.5, .65);
        error = null;
        if (page != null)
          clampPlacement(Size(page!.width.toDouble(), page!.height.toDouble()));
      });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not import signature. Allow photo access and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double get aspect {
    if (ink != null) {
      final b = ink!.bounds(weight);
      return b.width / b.height;
    }
    if (gallery != null) return gallery!.width / gallery!.height;
    return 2;
  }

  Size signatureSize(Size pageSize) {
    final width = pageSize.width * .30 * scale;
    return Size(width, width / aspect);
  }

  void clampPlacement(Size pageSize) {
    final dimensions = signatureSize(pageSize);
    final c = math.cos(rotation).abs(), s = math.sin(rotation).abs();
    var halfWidth = (dimensions.width * c + dimensions.height * s) / 2;
    var halfHeight = (dimensions.width * s + dimensions.height * c) / 2;
    final fit = math.min(
      1.0,
      math.min(
        pageSize.width / (halfWidth * 2),
        pageSize.height / (halfHeight * 2),
      ),
    );
    if (fit < 1) {
      scale *= fit;
      halfWidth *= fit;
      halfHeight *= fit;
    }
    center = Offset(
      center.dx
          .clamp(
            math.min(.5, halfWidth / pageSize.width),
            math.max(.5, 1 - halfWidth / pageSize.width),
          )
          .toDouble(),
      center.dy
          .clamp(
            math.min(.5, halfHeight / pageSize.height),
            math.max(.5, 1 - halfHeight / pageSize.height),
          )
          .toDouble(),
    );
  }

  _PlacedSignaturePainter painter() => _PlacedSignaturePainter(
    ink: ink,
    image: gallery,
    color: color,
    weight: weight,
    center: center,
    scale: scale,
    rotation: rotation,
    tint: tintGallery,
  );

  Future<void> done() async {
    if (busy || page == null) return;
    if (!hasSignature) {
      Navigator.pop(context);
      return;
    }
    setState(() => busy = true);
    ui.Image? output;
    ui.Picture? picture;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(page!, Offset.zero, Paint());
      painter().paint(
        canvas,
        Size(page!.width.toDouble(), page!.height.toDouble()),
      );
      picture = recorder.endRecording();
      output = await picture.toImage(page!.width, page!.height);
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode signature');
      if (mounted)
        Navigator.pop(
          context,
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not apply signature. Please try again.');
    } finally {
      output?.dispose();
      picture?.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: AppPalette.of(context).workspace,
      appBar: AppBar(
        backgroundColor: AppPalette.of(context).surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppText(
          'Add Signature',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: busy || page == null ? null : done,
            child: AppText(
              'Done',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: AppText(error!)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 35, 28, 16),
              child: page == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.topCenter,
                      child: AspectRatio(
                        aspectRatio: page!.width / page!.height,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final pageSize = Size(box.maxWidth, box.maxHeight);
                            final size = signatureSize(pageSize);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: RawImage(
                                    image: page,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                if (hasSignature) ...[
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(painter: painter()),
                                    ),
                                  ),
                                  Positioned(
                                    left:
                                        center.dx * pageSize.width -
                                        size.width / 2,
                                    top:
                                        center.dy * pageSize.height -
                                        size.height / 2,
                                    width: size.width,
                                    height: size.height,
                                    child: Transform.rotate(
                                      angle: rotation,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onScaleStart: busy
                                            ? null
                                            : (event) {
                                                startScale = scale;
                                                startRotation = rotation;
                                                startCenter = center;
                                                startFocal = event.focalPoint;
                                              },
                                        onScaleUpdate: busy
                                            ? null
                                            : (event) => setState(() {
                                                final delta =
                                                    event.focalPoint -
                                                    startFocal;
                                                center =
                                                    startCenter +
                                                    Offset(
                                                      delta.dx / pageSize.width,
                                                      delta.dy /
                                                          pageSize.height,
                                                    );
                                                scale =
                                                    (startScale * event.scale)
                                                        .clamp(.15, 3.0)
                                                        .toDouble();
                                                rotation =
                                                    startRotation +
                                                    event.rotation;
                                                clampPlacement(pageSize);
                                              }),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppPalette.of(context).primary,
                                            ),
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                left: -12,
                                                top: -12,
                                                child: handle(
                                                  'Remove signature',
                                                  Icons.close,
                                                  () => setState(() {
                                                    ink = null;
                                                    gallery?.dispose();
                                                    gallery = null;
                                                  }),
                                                ),
                                              ),
                                              Positioned(
                                                right: -12,
                                                top: -12,
                                                child: GestureDetector(
                                                  onPanUpdate: (event) =>
                                                      setState(() {
                                                        rotation +=
                                                            event.delta.dx *
                                                            .025;
                                                        clampPlacement(
                                                          pageSize,
                                                        );
                                                      }),
                                                  child: handle(
                                                    'Rotate signature',
                                                    Icons.rotate_right,
                                                    () => setState(() {
                                                      rotation += math.pi / 12;
                                                      clampPlacement(pageSize);
                                                    }),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: -12,
                                                bottom: -12,
                                                child: GestureDetector(
                                                  onPanUpdate: (event) => setState(() {
                                                    scale =
                                                        (scale +
                                                                (event.delta.dx +
                                                                        event
                                                                            .delta
                                                                            .dy) /
                                                                    pageSize
                                                                        .width *
                                                                    2)
                                                            .clamp(.15, 3.0)
                                                            .toDouble();
                                                    clampPlacement(pageSize);
                                                  }),
                                                  child: handle(
                                                    'Resize signature',
                                                    Icons.open_in_full,
                                                    () => setState(() {
                                                      scale = (scale * 1.1)
                                                          .clamp(.15, 3.0)
                                                          .toDouble();
                                                      clampPlacement(pageSize);
                                                    }),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: busy,
        child: hasSignature
            ? SignatureStyleBar(
                color: color,
                weight: weight,
                gallery: gallery != null,
                onColor: (value) => setState(() {
                  color = value;
                  tintGallery = true;
                }),
                onWeight: (value) => setState(() {
                  weight = value;
                  if (page != null)
                    clampPlacement(
                      Size(page!.width.toDouble(), page!.height.toDouble()),
                    );
                }),
              )
            : ReferenceToolbarSurface(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        action(
                          Icons.draw_outlined,
                          'Sign',
                          draw,
                          AppPalette.of(context).primary,
                        ),
                        action(
                          Icons.image_outlined,
                          'Gallery',
                          importSignature,
                          AppPalette.of(context).text,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );

  Widget handle(String label, IconData icon, VoidCallback action) => SizedBox(
    width: 24,
    height: 24,
    child: IconButton(
      tooltip: context.tr(label),
      padding: EdgeInsets.zero,
      onPressed: busy ? null : action,
      style: IconButton.styleFrom(
        backgroundColor: AppPalette.of(context).primary,
        foregroundColor: AppPalette.of(context).onPrimary,
        disabledBackgroundColor: AppPalette.of(context).selected,
        disabledForegroundColor: AppPalette.of(context).disabled),
      icon: Icon(icon, size: 13),
    ),
  );

  Widget action(
    IconData icon,
    String label,
    VoidCallback callback,
    Color color,
  ) => Expanded(
    child: AppToolbarAction(
      label: label,
      icon: icon,
      selected: color == AppPalette.of(context).primary,
      onPressed: busy || page == null ? null : callback,
    ),
  );
}

class _PlacedSignaturePainter extends CustomPainter {
  _PlacedSignaturePainter({
    this.ink,
    this.image,
    required this.color,
    required this.weight,
    required this.center,
    required this.scale,
    required this.rotation,
    required this.tint,
  });
  final SignatureInk? ink;
  final ui.Image? image;
  final Color color;
  final double weight, scale, rotation;
  final Offset center;
  final bool tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (ink == null && image == null) return;
    final bounds =
        ink?.bounds(weight) ??
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
    final width = size.width * .30 * scale,
        height = width * bounds.height / bounds.width;
    canvas.save();
    canvas.translate(center.dx * size.width, center.dy * size.height);
    canvas.rotate(rotation);
    if (ink != null) {
      canvas.translate(-width / 2, -height / 2);
      canvas.scale(width / bounds.width);
      canvas.translate(-bounds.left, -bounds.top);
      paintInk(canvas, ink!.strokes, color, weight);
    } else {
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withValues(alpha: weight / 70);
      if (tint) paint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
      canvas.drawImageRect(
        image!,
        bounds,
        Rect.fromLTWH(-width / 2, -height / 2, width, height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlacedSignaturePainter oldDelegate) => true;
}
