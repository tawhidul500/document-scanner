import 'dart:async';
import 'dart:math' as math;
import '../../data/app_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class CodeScanner extends StatefulWidget {
  const CodeScanner({super.key, required this.qrOnly});
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
  String? result;
  String? error;
  bool importing = false;
  bool disposed = false;
  bool active = true;
  Future<void> cameraTask = Future.value();
  double zoom = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  Future<void> start() {
    cameraTask = cameraTask.then((_) async {
      if (disposed || !mounted || !active || result != null || importing)
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
      if (disposed) return;
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

  void detect(BarcodeCapture capture) {
    if (!mounted || result != null) return;
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value == null || value.isEmpty) continue;
      if (widget.qrOnly != (code.format == BarcodeFormat.qrCode)) continue;
      setState(() => result = value);
      unawaited(AppPreferences.instance.scanFeedback());
      sweep.stop();
      unawaited(stop());
      return;
    }
  }

  void rescan() {
    setState(() => result = null);
    sweep.repeat(reverse: true);
    unawaited(start());
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
        if (capture != null) detect(capture);
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
    final uri = Uri.tryParse(value.trim());
    // Only open web links. Other payloads remain readable and copyable.
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      message('This code contains text, not a web link. Use Copy or Save.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        message('Could not open this link. You can copy it instead.');
      }
    } catch (_) {
      message('Could not open this link. You can copy it instead.');
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
    unawaited(cameraTask.then((_) => controller.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: result == null,
    onPopInvokedWithResult: (didPop, value) {
      if (!didPop && result != null) rescan();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF202020),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final width = math.min(
            size.width - 80,
            widget.qrOnly ? 238.0 : 281.0,
          );
          final frame = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: width,
            height: widget.qrOnly ? width * 1.09 : width * .64,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: controller,
                scanWindow: frame,
                onDetect: detect,
                errorBuilder: (_, exception) =>
                    const ColoredBox(color: Color(0xFF202020)),
              ),
              if (result == null) ...[
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: sweep,
                    builder: (_, child) => CustomPaint(
                      painter: _ScanOverlay(
                        frame: frame,
                        qr: widget.qrOnly,
                        progress: sweep.value,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 42,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (error != null) ...[
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          TextButton(
                            onPressed: start,
                            child: const Text('Retry'),
                          ),
                        ],
                        if (importing) const CircularProgressIndicator(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ValueListenableBuilder<MobileScannerState>(
                              valueListenable: controller,
                              builder: (_, state, child) => IconButton(
                                tooltip: 'Toggle flash',
                                color: Colors.white,
                                onPressed:
                                    state.isRunning &&
                                        state.torchState !=
                                            TorchState.unavailable
                                    ? () async {
                                        try {
                                          await controller.toggleTorch();
                                        } catch (_) {
                                          message('Flash is unavailable.');
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  state.torchState == TorchState.on
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  size: 28,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Scan from gallery',
                              color: Colors.white,
                              onPressed: importing ? null : gallery,
                              icon: const Icon(Icons.image_outlined, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: controller,
                          builder: (_, state, child) => Row(
                            children: [
                              IconButton(
                                tooltip: 'Zoom out',
                                color: Colors.white,
                                onPressed: state.isRunning
                                    ? () => setZoom(zoom - .1)
                                    : null,
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7,
                                    ),
                                  ),
                                  child: Slider(
                                    value: zoom,
                                    activeColor: Colors.white,
                                    inactiveColor: const Color(0xFF757575),
                                    semanticFormatterCallback: (v) =>
                                        '${(v * 100).round()} percent zoom',
                                    onChanged: state.isRunning ? setZoom : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Zoom in',
                                color: Colors.white,
                                onPressed: state.isRunning
                                    ? () => setZoom(zoom + .1)
                                    : null,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (result != null) ...[
                const ColoredBox(color: Color(0xFF202020)),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: CodeResultCard(
                      qrOnly: widget.qrOnly,
                      value: result!,
                      onClose: rescan,
                      onOpen: openResult,
                      onCopy: () async {
                        await Clipboard.setData(ClipboardData(text: result!));
                        message('Copied to clipboard');
                      },
                      onSave: () {
                        final value = result!;
                        // Clear the result so the back guard permits returning it.
                        setState(() => result = null);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) Navigator.of(context).pop(value);
                        });
                      },
                    ),
                  ),
                ),
              ],
              Positioned(
                top: 12,
                left: 4,
                child: SafeArea(
                  bottom: false,
                  child: IconButton(
                    color: Colors.white,
                    tooltip: result != null || widget.qrOnly
                        ? 'Back'
                        : 'Close scanner',
                    icon: Icon(
                      result != null || widget.qrOnly
                          ? Icons.arrow_back
                          : Icons.close,
                    ),
                    onPressed: () =>
                        result != null ? rescan() : Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class CodeResultCard extends StatelessWidget {
  const CodeResultCard({
    super.key,
    required this.qrOnly,
    required this.value,
    required this.onClose,
    required this.onOpen,
    required this.onCopy,
    required this.onSave,
  });
  final bool qrOnly;
  final String value;
  final VoidCallback onClose, onOpen, onCopy, onSave;

  @override
  Widget build(BuildContext context) => Container(
    width: 292,
    padding: const EdgeInsets.fromLTRB(27, 10, 26, 27),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: 30,
              child: Center(
                child: Text(
                  qrOnly ? 'QR Code Detected' : 'Bar Code Detected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              child: IconButton(
                tooltip: 'Scan again',
                onPressed: onClose,
                icon: const Icon(
                  Icons.cancel,
                  color: Color(0xFFD2D2D2),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          height: 130,
          width: double.infinity,
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(21),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(child: _action('Open', Icons.language, onOpen)),
            const SizedBox(width: 7),
            Expanded(child: _action('Copy', Icons.copy, onCopy)),
            const SizedBox(width: 7),
            Expanded(child: _action('Save', Icons.ios_share, onSave)),
          ],
        ),
      ],
    ),
  );

  Widget _action(String label, IconData icon, VoidCallback callback) =>
      ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF4D64FF),
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
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
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    final paint = Paint()
      ..color = qr ? const Color(0xFF267BFF) : const Color(0xFF5063FF)
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
            colors: [Color(0xD9267BFF), Color(0x00267BFF)],
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
