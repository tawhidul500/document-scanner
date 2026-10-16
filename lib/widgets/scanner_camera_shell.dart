import '../theme/app_motion.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/document_store.dart';

const scannerMint = Color(0xFF1FD1B4);

/// Shared live-camera chrome based on design/scanner-camera-screen.svg.
/// The sample paper in the SVG is intentionally replaced by the camera feed.
class ScannerCameraShell extends StatelessWidget {
  const ScannerCameraShell({super.key, required this.preview, required this.kind,
    required this.status, this.detected = false, this.busy = false,
    this.automatic = true, this.batch = false, this.showBatch = true,
    this.enhance = true, this.torch = false, this.onClose, this.onFlash,
    this.onAuto, this.onEnhance, this.onBatch, this.onMode, this.onCapture,
    this.onImages, this.onFiles, this.onDone, this.pageCount = 0});
  final Widget preview;
  final ScanKind kind;
  final String status;
  final bool detected, busy, automatic, batch, showBatch, enhance, torch;
  final VoidCallback? onClose, onFlash, onAuto, onEnhance, onCapture,
    onImages, onFiles, onDone;
  final ValueChanged<bool>? onBatch;
  final ValueChanged<ScanKind>? onMode;
  final int pageCount;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black, systemNavigationBarIconBrightness: Brightness.light),
    child: Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: Column(children: [
      SizedBox(height: 56, child: Row(children: [
        IconButton(onPressed: busy ? null : onClose, tooltip: context.tr('Close scanner'),
          icon: Image.asset('assets/scanner/close.png', width: 24, height: 24, excludeFromSemantics: true)),
        const Spacer(),
        if (onAuto != null) TextButton.icon(
          onPressed: busy ? null : onAuto,
          icon: Icon(automatic ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16, color: automatic ? scannerMint : Colors.white70),
          label: AppText(automatic ? 'Auto' : 'Manual',
            style: const TextStyle(color: Colors.white, fontSize: 14))),
        if (onEnhance != null) IconButton(
          onPressed: busy ? null : onEnhance,
          tooltip: context.tr(enhance ? 'Auto enhance on' : 'Auto enhance off'),
          icon: Icon(Icons.auto_fix_high, color: enhance ? scannerMint : Colors.white70, size: 22)),
        const Spacer(),
        IconButton(onPressed: busy ? null : onFlash, tooltip: context.tr('Toggle flash'),
          icon: torch ? const Icon(Icons.flash_on, color: Colors.white, size: 24) : Image.asset('assets/scanner/flash.png', width: 24, height: 24, excludeFromSemantics: true)),
      ])),
      Expanded(child: Stack(fit: StackFit.expand, children: [
        preview,
        Positioned(top: 16, left: 16, right: 16,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(duration: AppMotion.duration(context), curve: AppMotion.curve,
                width: 8, height: 8, decoration: BoxDecoration(
                color: detected ? scannerMint : Colors.white54, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(child: AppText(status, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
            ]),
          ))),
        if (showBatch) Positioned(bottom: 16, left: 0, right: 0,
          child: Center(child: Container(
            height: 47, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xD11E1E1E),
              borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final value in [false, true]) SizedBox(width: 86,
                child: TextButton(onPressed: busy ? null : () => onBatch?.call(value),
                  style: TextButton.styleFrom(
                    backgroundColor: batch == value ? Colors.white.withValues(alpha: .22) : Colors.transparent,
                    foregroundColor: batch == value ? Colors.white : const Color(0xFFCFD3D8),
                    padding: EdgeInsets.zero),
                  child: AppText(kind == ScanKind.idCard ? (value ? 'Both side' : 'One side') : (value ? 'Batch' : 'Single'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
            ]),
          ))),
        if (pageCount > 0) Positioned(right: 12, bottom: showBatch ? 74 : 16,
          child: FilledButton.icon(onPressed: busy ? null : onDone,
            style: FilledButton.styleFrom(backgroundColor: scannerMint, foregroundColor: Colors.black),
            icon: const Icon(Icons.check, size: 18), label: AppText('Done ({count})', arguments: {'count': pageCount}))),
      ])),
      ScannerModeStrip(kind: kind, enabled: !busy, onChanged: onMode),
      SizedBox(height: 128, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _import('Import Images', busy ? null : onImages),
        Semantics(button: true, label: context.tr(kind == ScanKind.qr || kind == ScanKind.barcode ? 'Read code' : 'Capture document'),
          child: InkResponse(onTap: busy ? null : onCapture, radius: 40,
            child: Container(width: 76, height: 76, padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: scannerMint, width: 4)),
              child: busy ? const CircularProgressIndicator(color: scannerMint) :
                const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F1F1))))),
        ),
        _import('Import Files', busy ? null : onFiles),
      ])),
    ])),
  ));

  Widget _import(String text, VoidCallback? action) => SizedBox(
    width: 105, child: TextButton(onPressed: action,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/scanner/${text == 'Import Images' ? 'images' : 'files'}.png', width: 26, height: 26, excludeFromSemantics: true), const SizedBox(height: 7),
        AppText(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ])));
}

class ScannerModeStrip extends StatefulWidget {
  const ScannerModeStrip({super.key, required this.kind, this.enabled = true, this.onChanged});
  final ScanKind kind;
  final bool enabled;
  final ValueChanged<ScanKind>? onChanged;
  @override
  State<ScannerModeStrip> createState() => _ScannerModeStripState();
}

class _ScannerModeStripState extends State<ScannerModeStrip> {
  late final PageController controller = PageController(
    initialPage: widget.kind.index, viewportFraction: .25);
  bool notifying = false;
  @override
  void didUpdateWidget(ScannerModeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind && controller.hasClients) {
      controller.jumpToPage(widget.kind.index);
      notifying = false;
    }
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(height: 48,
    child: NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        if (!notifying && widget.enabled && widget.onChanged != null && controller.hasClients) {
          final index=(controller.page ?? widget.kind.index.toDouble()).round().clamp(0,3).toInt();
          if (ScanKind.values[index] != widget.kind) {
            notifying=true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (!widget.enabled || widget.onChanged == null) return;
              widget.onChanged!(ScanKind.values[index]);
              notifying=false;
            });
          }
        }
        return false;
      },
      child: PageView.builder(controller: controller,
        physics: widget.enabled && widget.onChanged != null
          ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        itemCount: ScanKind.values.length,
        itemBuilder: (context,index) {
          final mode=ScanKind.values[index];
          return Semantics(selected: mode == widget.kind,
            child: TextButton(key: ValueKey('scanner-mode-${mode.name}'),
              onPressed: widget.enabled && widget.onChanged != null
                ? () => controller.animateToPage(index,
                    duration: AppMotion.duration(context), curve: AppMotion.curve)
                : null,
              style: TextButton.styleFrom(padding: EdgeInsets.zero,
                foregroundColor: mode == widget.kind ? scannerMint : const Color(0xFFCFD3D8),
                disabledForegroundColor: mode == widget.kind ? scannerMint : Colors.white38),
              child: AppText(mode.label, style: TextStyle(fontSize: 15,
                fontWeight: mode == widget.kind ? FontWeight.w700 : FontWeight.w700))));
        },
      ),
    ));
}
