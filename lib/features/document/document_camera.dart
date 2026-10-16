import 'package:pdf_scanner/l10n/app_localizations.dart';
import '../../widgets/scanner_camera_shell.dart';
import '../../data/document_store.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';
import '../../data/app_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'edge_detector.dart';
import 'native_document_detector.dart';
import 'page_processing.dart';
import 'id_card_processing.dart';

class DocumentCamera extends StatefulWidget {
  const DocumentCamera({
    super.key,
    required this.directory,
    this.remaining = 50,
    this.idCard = false,
    this.onModeChanged,
  });
  final Directory directory;
  final int remaining;
  final bool idCard;
  final ValueChanged<ScanKind>? onModeChanged;
  @override
  State<DocumentCamera> createState() => _DocumentCameraState();
}

class _DocumentCameraState extends State<DocumentCamera>
    with WidgetsBindingObserver {
  CameraController? camera;
  bool bothSides = false;
  bool get batchEnabled => widget.idCard ? bothSides : batch;
  Size idViewport = Size.zero;
  int get captureLimit =>
      widget.idCard ? (bothSides ? 2 : 1) : widget.remaining;
  final pages = <String>[];
  final gate = AutoCaptureGate();
  final detector = NativeDocumentDetector();
  final smoother = DocumentOutlineSmoother();
  int detectionEpoch = 0;
  Size previewViewport = Size.zero;

  void invalidateDetection() {
    detectionEpoch++;
    gate.reset();
    smoother.reset();
    quad = null;
  }

  bool visibleInPreview(DocumentQuad candidate, double width, double height) {
    if (previewViewport.isEmpty) return false;
    final scale = math.max(previewViewport.width / width, previewViewport.height / height);
    final left = (previewViewport.width - width * scale) / 2;
    final top = (previewViewport.height - height * scale) / 2;
    return candidate.points.every((p) {
      final x = left + p.x * width * scale, y = top + p.y * height * scale;
      return x >= 4 && x <= previewViewport.width - 4 &&
          y >= 4 && y <= previewViewport.height - 4;
    });
  }
  DocumentQuad? quad;
  bool enhance = true;
  double sharpness = 0;
  bool automatic = true,
      batch = false,
      busy = false,
      analyzing = false,
      torch = false;
  bool active = true, leaving = false;
  String? error;
  DateTime lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> cameraTask = Future.value();
  Future<void> frameIdle = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    configureCamera(true);
  }

  void configureCamera(bool open) {
    invalidateDetection();
    cameraTask = cameraTask
        .then((_) async {
          final previous = camera;
          camera = null;
          await previous?.dispose();
          if (!mounted || !open || !active || leaving) return;
          try {
            final devices = await availableCameras();
            if (!mounted || !active || leaving) return;
            if (devices.isEmpty) throw StateError('No camera found');
            final rear = devices.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => devices.first,
            );
            final next = CameraController(
              rear,
              ResolutionPreset.veryHigh,
              enableAudio: false,
              imageFormatGroup: Platform.isIOS
                  ? ImageFormatGroup.bgra8888
                  : ImageFormatGroup.yuv420,
            );
            camera = next;
            await next.initialize();
            await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
            if (!mounted || !active || leaving) return;
            await next.setFlashMode(torch ? FlashMode.torch : FlashMode.off);
            try {
              await next.setFocusMode(FocusMode.auto);
              await next.setExposureMode(ExposureMode.auto);
            } on CameraException { /* Optional on fixed-focus cameras. */ }
            await next.startImageStream(onFrame);
            if (mounted) setState(() => error = null);
          } catch (e) {
            if (mounted)
              setState(
                () => error = e is CameraException && e.code.contains('Access')
                    ? 'Allow camera access in your device settings, then tap Retry.'
                    : 'Could not start the camera. Close other camera apps and retry.',
              );
          }
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = 'Camera unavailable. Tap Retry.');
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    invalidateDetection();
    if (!busy) configureCamera(active);
  }

  @override
  void dispose() {
    leaving = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      cameraTask.then((_) async {
        final old = camera;
        camera = null;
        await old?.dispose();
      }),
    );
    super.dispose();
  }

  void onFrame(CameraImage frame) async {
    final current = camera;
    final now = DateTime.now();
    if (!mounted ||
        !active ||
        leaving ||
        busy ||
        analyzing ||
        current == null ||
        now.difference(lastFrame).inMilliseconds < 150)
      return;
    analyzing = true;
    final frameDone = Completer<void>();
    frameIdle = frameDone.future;
    final epoch = detectionEpoch;
    lastFrame = now;
    try {
      final plane = frame.planes.first;
      final rotation = portraitFrameRotation(ios: Platform.isIOS,
        width: frame.width, height: frame.height,
        sensorOrientation: current.description.sensorOrientation);
      final rotate = rotation == 90 || rotation == 270;
      final clockwise = rotation == 90;
      final ow = rotate ? frame.height : frame.width;
      final oh = rotate ? frame.width : frame.height;
      const w = 320;
      final h = (oh * w / ow).round();
      final gray = Uint8List(w * h);
      final bgra = frame.format.group == ImageFormatGroup.bgra8888;
      final stride = plane.bytesPerPixel ?? (bgra ? 4 : 1);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final ux = (x * ow / w).floor(), uy = (y * oh / h).floor();
          final sx = rotate ? (clockwise ? uy : frame.width - 1 - uy)
              : rotation == 180 ? frame.width - 1 - ux : ux;
          final sy = rotate ? (clockwise ? frame.height - 1 - ux : ux)
              : rotation == 180 ? frame.height - 1 - uy : uy;
          final offset = sy * plane.bytesPerRow + sx * stride;
          if (offset < 0 || offset + (bgra ? 2 : 0) >= plane.bytes.length)
            continue;
          gray[y * w + x] = bgra
              ? ((plane.bytes[offset] * 114 +
                            plane.bytes[offset + 1] * 587 +
                            plane.bytes[offset + 2] * 299) /
                        1000)
                    .round()
              : plane.bytes[offset];
        }
      }
      final quality = frameSharpness(gray, w, h);
      var detected = await detector.detectFrame(frame, rotation);
      if (!mounted || busy || !active || camera != current || leaving || epoch != detectionEpoch) return;
      if (widget.idCard && detected != null) {
        final points = detected.points.map((p) => math.Point(p.x*w,p.y*h)).toList();
        final cardWidth = (points[0].distanceTo(points[1]) + points[3].distanceTo(points[2]))/2;
        final cardHeight = (points[0].distanceTo(points[3]) + points[1].distanceTo(points[2]))/2;
        final ratio = math.max(cardWidth,cardHeight) / math.max(1,math.min(cardWidth,cardHeight));
        if (ratio < 1.2 || ratio > 2.1) detected = null;
      }
      setState(() { quad = smoother.add(detected); sharpness = quality; });
      if (automatic &&
          pages.length < captureLimit &&
          gate.update(detected, DateTime.now(), ready: quality >= 35 && detected != null &&
            visibleInPreview(detected, ow.toDouble(), oh.toDouble())))
        unawaited(capture());
    } catch (_) {
      if (mounted && camera == current && epoch == detectionEpoch) {
        smoother.reset();
        setState(() => quad = null);
        gate.reset();
      }
    } finally {
      analyzing = false;
      frameDone.complete();
    }
  }

  void notice(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(value)));
  }

  Future<void> append(Uint8List bytes, {bool fromCamera = false, String? sourcePath}) async {
    if (pages.length >= captureLimit) return;
    DocumentQuad? stillQuad;
    if (!widget.idCard && sourcePath != null) {
      try { stillQuad = await detector.detectFile(sourcePath); } catch (_) {
        // Keep the full photograph for the existing manual corner editor.
      }
    }
    var output = widget.idCard && fromCamera && !idViewport.isEmpty
        ? await compute(processIdCardCapture, <String, Object>{
            'bytes': bytes,
            'width': idViewport.width,
            'height': idViewport.height,
            'detectCard': true,
            'enhance': enhance,
          })
        : await compute(processPage, <String, Object>{
            'bytes': bytes,
            'detect': widget.idCard,
            if (stillQuad != null)
              'corners': stillQuad.points.expand((p) => [p.x, p.y]).toList(),
            'enhance': enhance,
          });
    if (widget.idCard) output = await compute(orientIdCard, output);
    final path =
        '${widget.directory.path}/${DateTime.now().microsecondsSinceEpoch}_${pages.length}.jpg';
    await File(path).writeAsBytes(output, flush: true);
    if (mounted) setState(() => pages.add(path));
  }

  Future<void> capture() async {
    final c = camera;
    if (busy || leaving || c == null || !c.value.isInitialized) return;
    if (pages.length >= captureLimit) {
      notice(
        widget.idCard
            ? 'Capture complete. Tap Done to preview.'
            : 'Page limit reached. Tap Done.',
      );
      return;
    }
    invalidateDetection();
    setState(() => busy = true);
    var captured = false;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await frameIdle; // Finish native frame detection before still-image detection.
      final shot = await c.takePicture();
      try {
        await append(await shot.readAsBytes(), fromCamera: true, sourcePath: shot.path);
        captured = true;
      } finally {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      gate.captured();
      unawaited(AppPreferences.instance.scanFeedback());
      if (!mounted) return;
      if (!batchEnabled) {
        finish();
        return;
      }
      if (pages.length >= captureLimit && !widget.idCard)
        setState(() => automatic = false);
      if (widget.idCard) {
        notice(
          pages.length >= captureLimit
              ? 'Ready. Tap Done to preview.'
              : 'Front captured. Turn the card over to scan the back.',
        );
      } else
        notice(
          context.tr('Page {count} captured. Move the document away before the next auto capture.', {'count': pages.length}),
        );
    } catch (_) {
      notice('Capture failed. Please try again.');
    } finally {
      if (mounted && !leaving) {
        setState(() => busy = false);
        if (active) {
          if (camera == c && c.value.isInitialized) {
            try {
              await c.startImageStream(onFrame);
            } catch (_) {
              configureCamera(true);
            }
          } else {
            configureCamera(true);
          }
        } else {
          configureCamera(false);
        }
        if (!captured) gate.reset();
      }
    }
  }

  Future<void> gallery() async {
    if (busy || leaving) return;
    if (pages.length >= captureLimit) {
      notice('Capture complete. Tap Done to preview.');
      return;
    }
    setState(() => busy = true);
    try {
      if (camera?.value.isStreamingImages ?? false)
        await camera!.stopImageStream();
      await frameIdle;
      final picker = ImagePicker();
      final images = batchEnabled && !widget.idCard ? await picker.pickMultiImage() : <XFile>[];
      if (!batchEnabled || widget.idCard) {
        final one = await picker.pickImage(source: ImageSource.gallery);
        if (one != null) images.add(one);
      }
      for (final image in images.take(captureLimit - pages.length)) {
        await append(await image.readAsBytes(), sourcePath: image.path);
      }
      if (!mounted) return;
      if (images.isNotEmpty && !batchEnabled) {
        finish();
        return;
      }
      gate.captured();
    } catch (_) {
      notice('Could not import this image. Try a JPEG or PNG.');
    } finally {
      if (mounted && !leaving) {
        setState(() => busy = false);
        configureCamera(active);
      }
    }
  }

  void finish() {
    if (!mounted || pages.isEmpty || leaving) return;
    if (widget.idCard && pages.length < captureLimit) {
      notice('Capture the back of your ID before continuing.');
      return;
    }
    leaving = true;
    Navigator.of(context).pop(List<String>.of(pages));
  }

  Future<void> close() async {
    if (busy) return;
    if (pages.isNotEmpty) {
      setState(() => busy = true);
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const AppText('Discard these scans?'),
          content: AppText('{count} unsaved pages will be discarded.', arguments: {'count': pages.length}),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Keep scanning'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AppText('Discard'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => busy = false);
      if (discard != true) return;
    }
    leaving = true;
    Navigator.of(context).pop();
  }

  Future<void> changeMode(ScanKind kind) async {
    if (busy || kind == (widget.idCard ? ScanKind.idCard : ScanKind.document)) return;
    if (pages.isNotEmpty) {
      notice('Tap Done to save these pages before switching scan type.');
      return;
    }
    if (widget.onModeChanged == null) return;
    setState(() => busy = true);
    gate.reset(clearRemoval: true);
    configureCamera(false);
    await cameraTask; // Never let two camera plugins own the hardware together.
    if (mounted) widget.onModeChanged!(kind);
  }

  Future<void> importFiles() async {
    if (busy || leaving) return;
    if (pages.length >= captureLimit) {
      notice('All sides captured. Tap Done to preview.');
      return;
    }
    setState(() => busy = true);
    try {
      if (camera?.value.isStreamingImages ?? false) await camera!.stopImageStream();
      await frameIdle;
      final path = await FlutterFileDialog.pickFile(params: OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        fileExtensionsFilter: widget.idCard ? ['jpg', 'jpeg', 'png'] : ['pdf', 'jpg', 'jpeg', 'png'],
        mimeTypesFilter: widget.idCard ? ['image/jpeg', 'image/png'] : ['application/pdf', 'image/jpeg', 'image/png'],
        copyFileToCacheDir: true));
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        if (widget.idCard && path.toLowerCase().endsWith('.pdf')) {
          notice('Import an image of one card side, not a PDF.');
          return;
        }
        if (path.toLowerCase().endsWith('.pdf')) {
          await for (final page in Printing.raster(bytes, dpi: 180)) {
            if (pages.length >= captureLimit) break;
            // Existing PDFs already have page bounds; do not crop their content.
            final output = await compute(processPage, <String,Object>{
              'bytes': await page.toPng(), 'enhance': enhance});
            final destination = '${widget.directory.path}/import_${DateTime.now().microsecondsSinceEpoch}.jpg';
            await File(destination).writeAsBytes(output, flush: true);
            if (mounted) setState(() => pages.add(destination));
          }
        } else {
          await append(bytes, sourcePath: path);
        }
        if (mounted && pages.isNotEmpty && !batchEnabled) finish();
      }
    } catch (_) {
      notice(widget.idCard ? 'Choose a JPEG or PNG image of one card side.' : 'Could not import that file. Choose a PDF, JPEG or PNG.');
    } finally {
      if (mounted && !leaving) {
        setState(() => busy = false);
        configureCamera(active);
      }
    }
  }

  Future<void> focus(Offset point) async {
    invalidateDetection();
    try {
      await camera?.setFocusPoint(point);
      await camera?.setExposurePoint(point);
    } on CameraException { /* Some cameras only support continuous focus. */ }
  }

  Widget livePreview() {
    final c = camera;
    if (error != null) return Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        AppText(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        TextButton(onPressed: () => configureCamera(true), child: const AppText('Retry')),
      ])));
    if (c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator(color: scannerMint));
    return LayoutBuilder(builder: (context, constraints) {
      idViewport = constraints.biggest;
      previewViewport = constraints.biggest;
      final width = math.min(c.value.previewSize!.width, c.value.previewSize!.height);
      final height = math.max(c.value.previewSize!.width, c.value.previewSize!.height);
      final zoom = math.max(constraints.maxWidth/width, constraints.maxHeight/height);
      final left = (constraints.maxWidth-width*zoom)/2;
      final top = (constraints.maxHeight-height*zoom)/2;
      return GestureDetector(onTapDown: (details) => focus(Offset(
        ((details.localPosition.dx-left)/(width*zoom)).clamp(0.0,1.0).toDouble(),
        ((details.localPosition.dy-top)/(height*zoom)).clamp(0.0,1.0).toDouble())),
        child: Stack(fit: StackFit.expand, children: [
          ClipRect(child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: width, height: height,
              child: Stack(fit: StackFit.expand, children: [
                CameraPreview(c),
                IgnorePointer(child: CustomPaint(painter: EdgePainter(quad))),
              ]))))),
          if (widget.idCard && quad == null) IgnorePointer(child: CustomPaint(
            painter: _IdCardGuidePainter(idCardGuide(constraints.maxWidth,constraints.maxHeight), ready: false))),
        ]));
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) unawaited(close()); },
    child: ScannerCameraShell(
      preview: livePreview(), kind: widget.idCard ? ScanKind.idCard : ScanKind.document,
      status: busy ? 'Processing…' : widget.idCard && pages.length >= captureLimit ? 'ID card ready • tap Done' : gate.awaitingRemoval ? 'Move page away for the next scan'
        : quad == null ? (widget.idCard ? (bothSides ? (pages.isEmpty ? 'Align ID card • front side' : 'Align ID card • back side') : 'Align the ID card') : 'Looking for document')
        : sharpness < 35 ? 'Hold steady • tap to focus'
        : widget.idCard
          ? (automatic ? 'ID card detected • hold still' : 'ID card detected')
          : automatic ? 'Document detected • hold still' : 'Document detected',
      detected: quad != null, busy: busy, automatic: automatic,
      enhance: enhance, torch: torch, batch: batchEnabled,
      onClose: close,
      onFlash: () async {
        try {
          await camera?.setFlashMode(torch ? FlashMode.off : FlashMode.torch);
          if (mounted) setState(() => torch = !torch);
        } catch (_) { notice('Flash is unavailable on this camera.'); }
      },
      onAuto: () => setState(() { automatic = !automatic; invalidateDetection(); gate.reset(clearRemoval: true); }),
      onEnhance: () => setState(() => enhance = !enhance),
      onBatch: (value) {
        if (pages.isNotEmpty) { notice('Finish this scan before changing page mode.'); return; }
        setState(() { if (widget.idCard) { bothSides=value; } else { batch=value; } });
      },
      onMode: widget.onModeChanged == null || pages.isNotEmpty ? null : changeMode,
      onCapture: pages.length >= captureLimit ? null : capture,
      onImages: pages.length >= captureLimit ? null : gallery,
      onFiles: pages.length >= captureLimit ? null : importFiles,
      onDone: widget.idCard && pages.length < captureLimit ? null : finish,
      pageCount: pages.length,
    ),
  );
}

class EdgePainter extends CustomPainter {
  EdgePainter(this.quad);
  final DocumentQuad? quad;
  @override
  void paint(Canvas canvas, Size size) {
    if (quad == null) return;
    final p = quad!.points;
    final path = Path()..moveTo(p[0].x * size.width, p[0].y * size.height);
    for (final point in p.skip(1))
      path.lineTo(point.x * size.width, point.y * size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0x1A1FD1B4));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1FD1B4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 156,
    );
    for (final point in p) {
      final center = Offset(point.x*size.width, point.y*size.height);
      canvas.drawCircle(center, size.width/56, Paint()..color = Colors.white);
      canvas.drawCircle(center, size.width/56, Paint()
        ..color = scannerMint ..style = PaintingStyle.stroke ..strokeWidth = size.width/130);
    }
  }

  @override
  bool shouldRepaint(EdgePainter oldDelegate) => oldDelegate.quad != quad;
}

class _IdCardGuidePainter extends CustomPainter {
  _IdCardGuidePainter(this.guide, {required this.ready});
  final List<double> guide;
  final bool ready;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(guide[0], guide[1], guide[2], guide[3]);
    final outline = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ]) {
      final dx = corner.dx == rect.left ? 36.0 : -36.0;
      final dy = corner.dy == rect.top ? 36.0 : -36.0;
      canvas.drawLine(corner, corner + Offset(dx, 0), outline);
      canvas.drawLine(corner, corner + Offset(0, dy), outline);
    }
    if (!ready) {
      final band = Rect.fromLTWH(
        rect.left,
        rect.center.dy,
        rect.width,
        rect.height * .42,
      );
      canvas.drawRect(band, Paint()..color = const Color(0x554B68FF));
      canvas.drawLine(
        band.topLeft,
        band.topRight,
        Paint()
          ..color = const Color(0xFF1FD1B4)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_IdCardGuidePainter oldDelegate) => true;
}
