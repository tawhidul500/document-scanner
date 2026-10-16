import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
part 'code_result_reference.dart';

/// Accessible fallback colors for large text, narrow screens and high contrast.
/// The reference layout uses the SVG's unmodified light colors.
class CodeResultColors {
  const CodeResultColors(this.dark);
  final bool dark;
  static CodeResultColors of(BuildContext context) =>
      CodeResultColors(Theme.of(context).brightness == Brightness.dark);

  List<Color> get gradient => dark
      ? const [Color(0xFF111C38), Color(0xFF1B2149), Color(0xFF312049)]
      : const [Color(0xFF2943B8), Color(0xFF4536BC), Color(0xFF642DB0)];
  Color get card => dark ? const Color(0xFF202D4D) : const Color(0x1AFFFFFF);
  Color get border => dark ? const Color(0xFF60729A) : const Color(0x59FFFFFF);
  Color get preview => dark ? const Color(0xFF111B35) : const Color(0x591B1F6B);
  Color get text => const Color(0xFFFFFFFF);
  Color get muted => const Color(0xE6FFFFFF);
  Color get badge => dark ? const Color(0xFF314161) : const Color(0x1FFFFFFF);
  Color get button => dark ? const Color(0xFF263958) : const Color(0xFFFFFFFF);
  Color get action => dark ? const Color(0xFFB8CCFF) : const Color(0xFF405BE0);
  Color get storeText => dark ? const Color(0xFFF3F6FF) : const Color(0xFF202020);
  Color get storeCaption => dark ? const Color(0xFFBBC8E4) : const Color(0xFF626274);
}

/// The camera stays stopped while this page is visible. The real status and
/// navigation bars use device insets; the SVG's fake home indicator is omitted.
class CodeResultScreen extends StatelessWidget {
  const CodeResultScreen({super.key, required this.qrOnly, required this.value,
    this.formatLabel, required this.onClose, required this.onOpen,
    required this.onCopy, required this.onSave, required this.onPromotion});
  final bool qrOnly;
  final String value;
  final String? formatLabel;
  final VoidCallback onClose, onOpen, onCopy, onSave, onPromotion;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (context.englishLayout && media.size.width >= 350 && !media.highContrast &&
        (media.textScaler.scale(15) - 15).abs() < .01) {
      return _ReferenceCodeResultScreen(qrOnly: qrOnly, value: value,
        formatLabel: formatLabel, onClose: onClose, onOpen: onOpen,
        onCopy: onCopy, onSave: onSave, onPromotion: onPromotion);
    }
    final colors = CodeResultColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: colors.gradient.last,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.gradient.last,
        body: DecoratedBox(
          key: const ValueKey('code-result-background'),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: colors.gradient, stops: const [0, .55, 1])),
          child: CustomPaint(
            painter: _ResultBackdrop(dark: colors.dark),
            child: SafeArea(
              child: SingleChildScrollView(
                key: const ValueKey('code-result-scroll'),
                padding: const EdgeInsets.only(bottom: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 60, child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              tooltip: context.tr('Back to scanner'), onPressed: onClose,
                              icon: _art('back', width: 20, height: 18,
                                color: colors.text, directional: true),
                            )),
                        )),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CodeResultCard(qrOnly: qrOnly, value: value,
                            formatLabel: formatLabel, onClose: onClose,
                            onOpen: onOpen, onCopy: onCopy, onSave: onSave)),
                        const SizedBox(height: 22),
                        _GeneratorPromotion(onTap: onPromotion),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CodeResultCard extends StatelessWidget {
  const CodeResultCard({super.key, required this.qrOnly, required this.value,
    this.formatLabel, required this.onClose, required this.onOpen,
    required this.onCopy, required this.onSave});
  final bool qrOnly;
  final String value;
  final String? formatLabel;
  final VoidCallback onClose, onOpen, onCopy, onSave;

  @override
  Widget build(BuildContext context) {
    final c = CodeResultColors.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return Container(
      key: const ValueKey('code-result-card'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          ConstrainedBox(constraints: const BoxConstraints(minHeight: 28),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(child: AppText(qrOnly ? 'QR Code Detected' : 'Barcode Detected',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontSize: 18,
                  height: 1.25, fontWeight: FontWeight.w600))))),
          Positioned(right: -12, top: -8,
            child: IconButton(tooltip: context.tr('Scan again'), onPressed: onClose,
              icon: Container(width: 28, height: 28, alignment: Alignment.center,
                decoration: BoxDecoration(color: c.badge, shape: BoxShape.circle),
                child: _art('close', width: 14, height: 14, color: c.text)))),
        ]),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('code-result-preview'),
          height: math.max(92.0, 92 * textScale),
          width: double.infinity,
          decoration: BoxDecoration(color: c.preview, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.symmetric(horizontal: qrOnly ? 20 : 16, vertical: 14),
          child: SingleChildScrollView(
            key: const ValueKey('code-result-payload-scroll'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!qrOnly) ...[
                Row(children: [
                  Flexible(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.badge,
                      borderRadius: BorderRadius.circular(12)),
                    child: AppText(formatLabel ?? 'Barcode',
                      key: const ValueKey('barcode-format'),
                      style: TextStyle(color: c.text, fontSize: 11,
                        height: 1.45, fontWeight: FontWeight.w700, letterSpacing: .6)))),
                  const SizedBox(width: 12),
                  const Spacer(),
                  ExcludeSemantics(child: _art('mini_barcode', width: 64, height: 30,
                    color: c.muted)),
                ]),
                const SizedBox(height: 5),
              ],
              SelectableText(value, textDirection: TextDirection.ltr,
                style: TextStyle(color: c.text, fontSize: qrOnly ? 15 : 22,
                  height: 1.3, fontWeight: qrOnly ? FontWeight.w400 : FontWeight.w600,
                  letterSpacing: qrOnly ? 0 : 2)),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final actions = [
            _ResultAction(label: qrOnly ? 'Open' : 'Search',
              artwork: qrOnly ? 'open' : 'search', onTap: onOpen),
            _ResultAction(label: 'Copy', artwork: 'copy', onTap: onCopy),
            _ResultAction(label: 'Save', artwork: 'save', onTap: onSave),
          ];
          // Keep the SVG's three buttons at its reference size. Small screens
          // and larger accessibility text get full-width, readable controls.
          if (constraints.maxWidth < 290 || textScale > 1.2) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10), actions[i],
              ]]);
          }
          return Row(children: [for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 11.5), Expanded(child: actions[i]),
          ]]);
        }),
      ]),
    );
  }
}

class _ResultAction extends StatelessWidget {
  const _ResultAction({required this.label, required this.artwork, required this.onTap});
  final String label, artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CodeResultColors.of(context);
    return Semantics(button: true, child: Material(
      color: c.button, elevation: 2, shadowColor: const Color(0x30000000),
      borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap,
        child: Container(constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _art(artwork, width: 18, height: 20, color: c.action),
            const SizedBox(width: 6),
            Flexible(child: AppText(label, textAlign: TextAlign.center,
              style: TextStyle(color: c.action, fontSize: 15,
                height: 1.2, fontWeight: FontWeight.w600))),
          ])),
      ),
    ));
  }
}

class _GeneratorPromotion extends StatelessWidget {
  const _GeneratorPromotion({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = CodeResultColors.of(context);
    return Column(children: [
      Padding(padding: const EdgeInsets.only(left: 20, right: 16),
        child: Row(children: [
          Expanded(child: AppText('TRY OUR OTHER APP',
            style: TextStyle(color: c.muted, fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 1.4))),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: c.badge, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7,
                decoration: const BoxDecoration(color: Color(0xFF7CFFB2), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              AppText('FREE', style: TextStyle(color: c.text, fontSize: 11,
                height: 1.25, fontWeight: FontWeight.w700, letterSpacing: .6)),
            ])),
        ])),
      const SizedBox(height: 54),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ExcludeSemantics(child: Image.asset('assets/scan_results/illustration.png',
          width: 295, height: 150, fit: BoxFit.contain))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
          children: [for (final label in ['QR Code', 'Barcode', 'Wi-Fi · vCard'])
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: c.badge, borderRadius: BorderRadius.circular(13)),
              child: AppText(label, style: TextStyle(color: c.text,
                fontSize: 12, height: 1.33, fontWeight: FontWeight.w600))),
          ])),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppText('Make your own\nQR & Barcodes', textAlign: TextAlign.center,
          style: TextStyle(color: c.text, fontSize: 23, height: 27 / 23,
            fontWeight: FontWeight.w800))),
      const SizedBox(height: 5),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppText('Create, customize and share in seconds.', textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 13, height: 1.4))),
      const SizedBox(height: 15),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Semantics(button: true, label: context.tr('Get it on Google Play'),
          excludeSemantics: true,
          child: Material(color: c.button, elevation: 8,
            shadowColor: const Color(0x591B1F6B),
            borderRadius: BorderRadius.circular(26), clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap,
              child: Container(constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  const Spacer(),
                  _art('play', width: 22, height: 24, color: c.dark ? c.action : null),
                  const SizedBox(width: 9),
                  Flexible(flex: 6, child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppText('GET IT ON', style: TextStyle(color: c.storeCaption,
                        fontSize: 10, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: .8)),
                      AppText('Google Play', style: TextStyle(color: c.storeText,
                        fontSize: 17, height: 1.2, fontWeight: FontWeight.w700)),
                    ])),
                  const Spacer(),
                  Container(width: 28, height: 28, alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(colors: c.dark
                        ? const [Color(0xFF405BE0), Color(0xFF7941D1)]
                        : const [Color(0xFF4B68FF), Color(0xFF8A4DFF)])),
                    child: _art('next', width: 16, height: 14,
                      color: Colors.white, directional: true)),
                ])),
            ),
          ),
        )),
    ]);
  }
}

Widget _art(String name, {required double width, required double height,
  Color? color, bool directional = false}) => Image.asset(
    'assets/scan_results/$name.png', width: width, height: height,
    color: color, colorBlendMode: BlendMode.srcIn, fit: BoxFit.contain,
    matchTextDirection: directional, excludeFromSemantics: true);

class _ResultBackdrop extends CustomPainter {
  const _ResultBackdrop({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 375;
    final shine = Paint()..shader = RadialGradient(
      colors: [Colors.white.withValues(alpha: dark ? .04 : .08), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(300 * scale, 0), radius: 320 * scale));
    canvas.drawRect(Offset.zero & size, shine);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (final radius in [90.0, 135.0]) {
      ring.color = Colors.white.withValues(alpha: dark ? .035 : .045);
      canvas.drawCircle(Offset(360 * scale, 60 * scale), radius * scale, ring);
    }
    for (final radius in [110.0, 160.0]) {
      ring.color = Colors.white.withValues(alpha: dark ? .03 : .04);
      canvas.drawCircle(Offset(10 * scale, size.height - 52), radius * scale, ring);
    }
  }
  @override
  bool shouldRepaint(_ResultBackdrop oldDelegate) => oldDelegate.dark != dark;
}
