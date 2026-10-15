import '../../data/app_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'edge_detector.dart';
import 'page_processing.dart';
import 'id_card_processing.dart';

class DocumentCamera extends StatefulWidget {
  const DocumentCamera({
    super.key,
    required this.directory,
    this.remaining = 50,
    this.idCard = false,
  });
  final Directory directory;
  final int remaining;
  final bool idCard;
  @override
  State<DocumentCamera> createState() => _DocumentCameraState();
}

class _DocumentCameraState extends State<DocumentCamera>
    with WidgetsBindingObserver {
  CameraController? camera;
  bool bothSides = false;
  Size idViewport = Size.zero;
  int get captureLimit =>
      widget.idCard ? (bothSides ? 2 : 1) : widget.remaining;
  final pages = <String>[];
  final gate = AutoCaptureGate();
  DocumentQuad? quad;
  bool automatic = true,
      batch = false,
      busy = false,
      analyzing = false,
      torch = false;
  bool active = true, leaving = false;
  String? error;
  DateTime lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> cameraTask = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    configureCamera(true);
  }

  void configureCamera(bool open) {
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
              ResolutionPreset.high,
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
    gate.reset();
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
        now.difference(lastFrame).inMilliseconds < 220)
      return;
    analyzing = true;
    lastFrame = now;
    try {
      final plane = frame.planes.first;
      // Locked portrait preview. iOS commonly supplies already-upright buffers.
      final rotate = frame.width > frame.height;
      final clockwise = current.description.sensorOrientation != 270;
      final ow = rotate ? frame.height : frame.width;
      final oh = rotate ? frame.width : frame.height;
      const w = 200;
      final h = (oh * w / ow).round();
      final gray = Uint8List(w * h);
      final bgra = frame.format.group == ImageFormatGroup.bgra8888;
      final stride = plane.bytesPerPixel ?? (bgra ? 4 : 1);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final ux = (x * ow / w).floor(), uy = (y * oh / h).floor();
          final sx = rotate ? (clockwise ? uy : frame.width - 1 - uy) : ux;
          final sy = rotate ? (clockwise ? frame.height - 1 - ux : ux) : uy;
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
      var detected = await compute(detectDocument, <String, Object>{
        'gray': gray,
        'width': w,
        'height': h,
      });
      if (!mounted || busy || !active || camera != current || leaving) return;
      if (widget.idCard && detected != null) {
        final points = detected.points;
        final cardWidth =
            (points[0].distanceTo(points[1]) +
                points[3].distanceTo(points[2])) *
            w /
            2;
        final cardHeight =
            (points[0].distanceTo(points[3]) +
                points[1].distanceTo(points[2])) *
            h /
            2;
        final ratio = cardHeight == 0 ? 0 : cardWidth / cardHeight;
        if (ratio < 1.2 || ratio > 2.1) detected = null;
        if (!idViewport.isEmpty && detected != null) {
          final zoom = math.max(idViewport.width / w, idViewport.height / h);
          final offset = Offset(
            (idViewport.width - w * zoom) / 2,
            (idViewport.height - h * zoom) / 2,
          );
          final guide = idCardGuide(idViewport.width, idViewport.height);
          final allowed = Rect.fromLTWH(
            guide[0],
            guide[1],
            guide[2],
            guide[3],
          ).inflate(12);
          if (points.any(
            (p) => !allowed.contains(
              Offset(p.x * w * zoom, p.y * h * zoom) + offset,
            ),
          ))
            detected = null;
        }
      }
      setState(() => quad = detected);
      if (automatic &&
          pages.length < captureLimit &&
          gate.update(detected, DateTime.now()))
        unawaited(capture());
    } catch (_) {
      if (mounted) setState(() => quad = null);
      gate.reset();
    } finally {
      analyzing = false;
    }
  }

  void notice(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> append(Uint8List bytes, {bool fromCamera = false}) async {
    if (pages.length >= captureLimit) return;
    final output = widget.idCard && fromCamera && !idViewport.isEmpty
        ? await compute(processIdCardCapture, <String, Object>{
            'bytes': bytes,
            'width': idViewport.width,
            'height': idViewport.height,
          })
        : await compute(processPage, <String, Object>{
            'bytes': bytes,
            'detect': true,
          });
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
            ? 'Capture complete. Tap the arrow to preview.'
            : 'Page limit reached. Tap Done.',
      );
      return;
    }
    setState(() => busy = true);
    var captured = false;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      final shot = await c.takePicture();
      try {
        await append(await shot.readAsBytes(), fromCamera: true);
        captured = true;
      } finally {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      gate.captured();
      unawaited(AppPreferences.instance.scanFeedback());
      if (!mounted) return;
      if (!batch && !widget.idCard) {
        finish();
        return;
      }
      if (pages.length >= captureLimit && !widget.idCard)
        setState(() => automatic = false);
      if (widget.idCard) {
        notice(
          pages.length >= captureLimit
              ? 'Ready. Tap the arrow to preview.'
              : 'Front captured. Turn the card over to scan the back.',
        );
      } else
        notice(
          'Page ${pages.length} captured. Move the document away before the next auto capture.',
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
      notice('Capture complete. Tap the arrow to preview.');
      return;
    }
    setState(() => busy = true);
    try {
      if (camera?.value.isStreamingImages ?? false)
        await camera!.stopImageStream();
      final picker = ImagePicker();
      final images = batch ? await picker.pickMultiImage() : <XFile>[];
      if (!batch) {
        final one = await picker.pickImage(source: ImageSource.gallery);
        if (one != null) images.add(one);
      }
      for (final image in images.take(captureLimit - pages.length)) {
        await append(await image.readAsBytes());
      }
      if (!mounted) return;
      if (images.isNotEmpty && !batch && !widget.idCard) {
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
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard these scans?'),
          content: Text('${pages.length} unsaved pages will be discarded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep scanning'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    leaving = true;
    Navigator.of(context).pop();
  }

  Widget buildIdCamera() {
    final c = camera;
    final ready = pages.length == captureLimit;
    final side = pages.isEmpty ? 'front' : 'back';
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(close());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B101C),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    IconButton(
                      onPressed: busy ? null : close,
                      tooltip: 'Close ID scanner',
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: busy || ready
                          ? null
                          : () => setState(() {
                              automatic = !automatic;
                              gate.reset();
                            }),
                      icon: const Icon(
                        Icons.tune,
                        size: 16,
                        color: Colors.white70,
                      ),
                      label: Text(
                        automatic ? 'Auto' : 'Manual',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: busy || c == null || !c.value.isInitialized
                          ? null
                          : () async {
                              try {
                                await c.setFlashMode(
                                  torch ? FlashMode.off : FlashMode.torch,
                                );
                                if (mounted) setState(() => torch = !torch);
                              } catch (_) {
                                notice('Flash is unavailable on this camera.');
                              }
                            },
                      tooltip: 'Toggle flash',
                      icon: Icon(
                        torch ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    idViewport = Size(box.maxWidth, box.maxHeight);
                    final guide = idCardGuide(box.maxWidth, box.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (c != null && c.value.isInitialized)
                          ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 1000 / c.value.aspectRatio,
                                height: 1000,
                                child: CameraPreview(c),
                              ),
                            ),
                          ),
                        if (error != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  TextButton(
                                    onPressed: () => configureCamera(true),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (c == null || !c.value.isInitialized)
                          const Center(child: CircularProgressIndicator()),
                        if (error == null) ...[
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _IdCardGuidePainter(guide, ready: ready),
                            ),
                          ),
                          if (bothSides)
                            Positioned(
                              top: guide[1] - 40,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      pages.isEmpty ? 'Front' : 'Back',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: guide[1] + guide[3] + 16,
                            left: 12,
                            right: 12,
                            child: Text(
                              ready
                                  ? 'Ready to preview'
                                  : 'Scan the $side side of your ID',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final item in [
                                (false, 'One Side'),
                                (true, 'Both Sides'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: TextButton(
                                    onPressed:
                                        busy || (pages.length > 1 && !item.$1)
                                        ? null
                                        : () => setState(() {
                                            bothSides = item.$1;
                                            gate.reset();
                                            if (pages.length < captureLimit)
                                              automatic = true;
                                          }),
                                    style: TextButton.styleFrom(
                                      backgroundColor: bothSides == item.$1
                                          ? const Color(0xFF4B68FF)
                                          : Colors.black54,
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: Colors.white38,
                                      minimumSize: const Size(0, 24),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide(
                                        color: bothSides == item.$1
                                            ? Colors.transparent
                                            : Colors.white,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      item.$2,
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      onPressed: busy || ready ? null : gallery,
                      tooltip: 'Import ID image',
                      icon: Icon(
                        Icons.photo_library_outlined,
                        color: ready ? Colors.white38 : Colors.white,
                        size: 30,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Capture ID $side',
                      child: InkWell(
                        onTap: busy || ready ? null : capture,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4B68FF),
                              width: 4,
                            ),
                          ),
                          child: busy
                              ? const CircularProgressIndicator()
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ready
                                        ? const Color(0xFF303950)
                                        : const Color(0xFF4B68FF),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: busy || !ready ? null : finish,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pages.isNotEmpty)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(pages.last),
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: -4,
                                  top: -5,
                                  child: CircleAvatar(
                                    radius: 7,
                                    backgroundColor: const Color(0xFF4B68FF),
                                    child: Text(
                                      '${pages.length}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.credit_card,
                              color: Colors.white38,
                              size: 28,
                            ),
                          Icon(
                            Icons.chevron_right,
                            size: 30,
                            color: ready ? Colors.white : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = camera;
    if (widget.idCard) return buildIdCamera();
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(close());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B101C),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: busy ? null : close,
                      tooltip: 'Close scanner',
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Toggle flash',
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                await c?.setFlashMode(
                                  torch ? FlashMode.off : FlashMode.torch,
                                );
                                if (mounted) setState(() => torch = !torch);
                              } catch (_) {
                                notice('Flash is unavailable on this camera.');
                              }
                            },
                      icon: Icon(
                        torch ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              TextButton(
                                onPressed: () => configureCamera(true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : c == null || !c.value.isInitialized
                      ? const CircularProgressIndicator()
                      : AspectRatio(
                          aspectRatio: 1 / c.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(c),
                              IgnorePointer(
                                child: CustomPaint(painter: EdgePainter(quad)),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 8,
                                right: 8,
                                child: Text(
                                  gate.awaitingRemoval
                                      ? 'Move the page away to scan the next one'
                                      : quad == null
                                      ? 'Place the full document inside the camera view'
                                      : automatic
                                      ? 'Hold still to capture'
                                      : 'Tap the shutter to capture',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    backgroundColor: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              Container(
                color: const Color(0xFF191919),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: busy ? null : gallery,
                          tooltip: 'Import image',
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Capture document',
                          child: InkWell(
                            onTap: busy ? null : capture,
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: busy
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: busy || pages.isEmpty ? null : finish,
                          child: Text(
                            'Done (${pages.length})',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Manual')),
                        ButtonSegment(value: true, label: Text('Auto capture')),
                      ],
                      selected: {automatic},
                      onSelectionChanged: busy
                          ? null
                          : (v) => setState(() {
                              automatic = v.first;
                              gate.reset();
                            }),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? const Color(0xFF4B68FF)
                              : Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Single'),
                          selected: !batch,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => batch = false),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Batch'),
                          selected: batch,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => batch = true),
                        ),
                      ],
                    ),
                    if (pages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${pages.length} page${pages.length == 1 ? '' : 's'} ready • Tap Done to review',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    canvas.drawPath(path, Paint()..color = const Color(0x334B68FF));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4B68FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
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
          ..color = const Color(0xFF4B68FF)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_IdCardGuidePainter oldDelegate) => true;
}
