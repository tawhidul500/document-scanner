import 'package:pdf_scanner/l10n/app_localizations.dart';
import '../../widgets/scanner_camera_shell.dart';
import '../../data/document_store.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../data/app_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'code_scan_geometry.dart';
import 'code_result_actions.dart';
import 'code_result_screen.dart';
export 'code_result_screen.dart' show CodeResultCard, CodeResultScreen;

class CodeScanner extends StatefulWidget {
  const CodeScanner({super.key, required this.qrOnly, this.onModeChanged});
  final ValueChanged<ScanKind>? onModeChanged;
  final bool qrOnly;

  @override
  State<CodeScanner> createState() => _CodeScannerState();
}

class _CodeScannerState extends State<CodeScanner>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    formats: widget.qrOnly
        ? [BarcodeFormat.qrCode]
        : [
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.code93,
            BarcodeFormat.codabar,
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.itf14,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.pdf417,
            BarcodeFormat.dataMatrix,
            BarcodeFormat.aztec,
          ],
  );
  late final AnimationController sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  String? result, pendingCode;
  BarcodeFormat? resultFormat, pendingFormat;
  bool savingResult = false;
  DateTime? pendingAt;
  bool automatic = true;
  bool released = false;
  bool changingMode = false;
  String? error;
  bool importing = false;
  bool disposed = false;
  bool active = true;
  Future<void> cameraTask = Future.value();
  double zoom = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AppPreferences.instance.prepareScanFeedback());
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  Future<void> start() {
    cameraTask = cameraTask.then((_) async {
      if (disposed || released || changingMode || !mounted || !active || result != null || importing)
        return;
      try {
        if (!controller.value.isRunning) await controller.start();
        if (mounted) setState(() => error = null);
      } catch (_) {
        if (mounted)
          setState(
            () => error =
                'Camera unavailable. Allow camera access in device settings, then retry.',
          );
      }
    });
    return cameraTask;
  }

  Future<void> stop() {
    cameraTask = cameraTask.then((_) async {
      if (disposed || released) return;
      try {
        await controller.stop();
      } catch (_) {
        /* Already stopped. */
      }
    });
    return cameraTask;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      if (result == null && !importing) unawaited(start());
    } else {
      unawaited(stop());
    }
  }

  void detect(BarcodeCapture capture, {bool force = false}) {
    if (!mounted || changingMode || result != null) return;
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value == null || value.isEmpty) continue;
      if (widget.qrOnly != (code.format == BarcodeFormat.qrCode)) continue;
      if (!automatic && !force) {
        pendingCode = value;
        pendingFormat = code.format;
        pendingAt = DateTime.now();
        return;
      }
      acceptResult(value, code.format);
      return;
    }
  }

  void acceptResult(String value, BarcodeFormat? format) {
    // Automatic detection, imported images and manual capture share one guard.
    if (!mounted || disposed || released || changingMode || result != null) return;
    setState(() { result = value; resultFormat = format; });
    sweep.stop();
    unawaited(AppPreferences.instance.scanFeedback());
    unawaited(stop());
  }

  void rescan() {
    if (savingResult) return;
    setState(() {
      result = null; resultFormat = null;
      pendingCode = null; pendingFormat = null; pendingAt = null;
    });
    sweep.repeat(reverse: true);
    unawaited(start());
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(text)));
  }

  Future<void> gallery() async {
    if (importing) return;
    setState(() => importing = true);
    await stop();
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (image != null) {
        final capture = await controller.analyzeImage(image.path);
        if (!mounted) return;
        if (capture != null) detect(capture, force: true);
        if (result == null)
          message(
            widget.qrOnly
                ? 'No QR code found in this image.'
                : 'No barcode found in this image.',
          );
      }
    } catch (_) {
      message('Could not scan this image. Try another photo.');
    } finally {
      if (mounted) {
        setState(() => importing = false);
        if (result == null) await start();
      }
    }
  }

  Future<void> openResult() async {
    final value = result;
    if (value == null) return;
    final uri = codeResultUri(qrOnly: widget.qrOnly, value: value);
    if (uri == null) {
      message('This code contains text, not a web link. Use Copy or Save.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        message('Could not open the browser. You can copy the result instead.');
      }
    } catch (_) {
      message('Could not open the browser. You can copy the result instead.');
    }
  }

  Future<void> copyResult() async {
    final value = result;
    if (value == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      message('Copied to clipboard');
    } catch (_) {
      message('Could not copy this result. Please try again.');
    }
  }

  void saveResult() {
    final value = result;
    if (value == null || savingResult) return;
    // Allow this intentional route pop without rebuilding/restarting the camera.
    setState(() => savingResult = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(value);
    });
  }

  Future<void> openPromotion() async {
    final uri = generatorAppUri(qrGeneratorAppUrl);
    if (uri == null) {
      message('This app link is not available in this version yet.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        message('Could not open the app page. Please try again.');
      }
    } catch (_) {
      message('Could not open the app page. Please try again.');
    }
  }

  Future<void> setZoom(double value) async {
    setState(() => zoom = value.clamp(0.0, 1.0).toDouble());
    try {
      await controller.setZoomScale(zoom);
    } catch (_) {
      message('Zoom is unavailable on this camera.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sweep.dispose();
    disposed = true;
    if (!released) unawaited(cameraTask.then((_) => controller.dispose()));
    super.dispose();
  }

  Future<void> changeMode(ScanKind kind) async {
    if (importing || changingMode || widget.onModeChanged == null ||
        kind == (widget.qrOnly ? ScanKind.qr : ScanKind.barcode)) return;
    setState(() => changingMode = true);
    await stop();
    await controller.dispose();
    released = true;
    if (mounted) widget.onModeChanged!(kind);
  }

  Future<void> importFiles() async {
    if (importing || changingMode) return;
    setState(() => importing = true);
    await stop();
    try {
      final path = await FlutterFileDialog.pickFile(params: const OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        fileExtensionsFilter: ['jpg','jpeg','png'],
        mimeTypesFilter: ['image/jpeg','image/png'], copyFileToCacheDir: true));
      if (path != null) {
        final capture = await controller.analyzeImage(path);
        if (!mounted) return;
        if (capture != null) detect(capture, force: true);
        if (result == null) message('No matching code found in that image.');
      }
    } catch (_) { message('Could not read that image file.'); }
    finally {
      if (mounted) {
        setState(() => importing = false);
        if (result == null) await start();
      }
    }
  }

  void readCode() {
    if (pendingCode == null || pendingAt == null ||
        DateTime.now().difference(pendingAt!).inMilliseconds > 800) {
      message('Keep the code inside the guide until it is readable.'); return;
    }
    acceptResult(pendingCode!, pendingFormat);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object>(
    canPop: result == null || savingResult,
    onPopInvokedWithResult: (didPop, value) { if (!didPop && result != null) rescan(); },
    child: result != null ? CodeResultScreen(
      qrOnly: widget.qrOnly, value: result!,
      formatLabel: barcodeFormatLabel(resultFormat),
      onClose: rescan, onOpen: openResult, onCopy: copyResult,
      onSave: saveResult, onPromotion: openPromotion,
    ) : ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context,state,_) => ScannerCameraShell(
        kind: widget.qrOnly ? ScanKind.qr : ScanKind.barcode,
        status: error ?? (widget.qrOnly ? 'Align the QR code' : 'Align the barcode'),
        busy: importing || changingMode, showBatch: false, automatic: automatic,
        torch: state.torchState == TorchState.on,
        onAuto: () => setState(() { automatic=!automatic; pendingCode=null; pendingFormat=null; pendingAt=null; }),
        onClose: () => Navigator.of(context).pop(),
        onFlash: () async {
          try { await controller.toggleTorch(); } catch (_) { message('Flash is unavailable.'); }
        },
        onMode: widget.onModeChanged == null ? null : changeMode,
        onCapture: readCode, onImages: gallery, onFiles: importFiles,
        preview: LayoutBuilder(builder: (context,constraints) {
          final size=constraints.biggest;
          final width=math.min(size.width-48, widget.qrOnly ? 250.0 : 300.0);
          final frame=Rect.fromCenter(center: Offset(size.width/2,size.height/2),
            width: width, height: widget.qrOnly ? width : width*.55);
          return Stack(fit: StackFit.expand, children: [
            MobileScanner(controller: controller, scanWindow: widget.qrOnly ? frame : BarcodeScanGeometry(frame).scanWindow, onDetect: detect,
              errorBuilder: (_,exception) => const ColoredBox(color: Colors.black)),
            IgnorePointer(child: AnimatedBuilder(animation: sweep,
              builder: (_,child) => CustomPaint(painter: _ScanOverlay(
                frame: frame, qr: widget.qrOnly, progress: sweep.value)))),
            if (error != null) Center(child: TextButton(onPressed: start, child: const AppText('Retry'))),
          ]);
        }),
      ),
    ),
  );
}

class _ScanOverlay extends CustomPainter {
  const _ScanOverlay({
    required this.frame,
    required this.qr,
    required this.progress,
  });
  final Rect frame;
  final bool qr;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = BarcodeScanGeometry(frame);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (qr) {
      outside.addRect(frame);
    } else {
      outside.addRRect(geometry.opening);
    }
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    if (!qr) {
      // The mask and corner strokes now share the same rounded rectangle.
      // Nothing is drawn or decoded outside the rounded blue guide.
      geometry.paintCorners(canvas);
      return;
    }
    final paint = Paint()
      ..color = scannerMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = qr ? 4 : 6
      ..strokeCap = StrokeCap.round;
    const length = 30.0;
    final radius = qr ? 0.0 : 20.0;
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      final dx = corner.dx == frame.left ? 1.0 : -1.0;
      final dy = corner.dy == frame.top ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(corner.dx, corner.dy + dy * length)
        ..lineTo(corner.dx, corner.dy + dy * radius)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx + dx * radius,
          corner.dy,
        )
        ..lineTo(corner.dx + dx * length, corner.dy);
      canvas.drawPath(path, paint);
    }
    if (qr) {
      final band = Rect.fromLTWH(
        frame.left,
        frame.top + (frame.height - 95) * progress,
        frame.width,
        95,
      );
      canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD91FD1B4), Color(0x001FD1B4)],
          ).createShader(band),
      );
    }
  }

  @override
  bool shouldRepaint(_ScanOverlay oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.progress != progress ||
      oldDelegate.qr != qr;
}
