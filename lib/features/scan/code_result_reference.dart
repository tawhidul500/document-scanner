part of 'code_result_screen.dart';

/// SVG coordinate space. These values are intentionally not inferred from text
/// height or default Material padding. Larger text uses the adaptive screen.
class _ReferenceCodeResultScreen extends StatelessWidget {
  const _ReferenceCodeResultScreen({required this.qrOnly, required this.value,
    required this.formatLabel, required this.onClose, required this.onOpen,
    required this.onCopy, required this.onSave, required this.onPromotion});
  final bool qrOnly;
  final String value;
  final String? formatLabel;
  final VoidCallback onClose, onOpen, onCopy, onSave, onPromotion;

  @override
  Widget build(BuildContext context) {
    final c = CodeResultColors.of(context);
    final dark = c.dark;
    final endColor = dark ? c.gradient.last : const Color(0xFF8A4DFF);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: endColor,
        systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(backgroundColor: endColor,
        body: LayoutBuilder(builder: (context, constraints) {
          final width = math.min(520.0, constraints.maxWidth);
          final scale = width / 375;
          // The SVG already reserves 24px above its visible controls. Add only
          // extra notch space; do not shift the whole page by a second SafeArea.
          final inset = MediaQuery.paddingOf(context);
          final extraTop = math.max(0.0, inset.top / scale - 24);
          final height = math.max(812.0 + extraTop + inset.bottom / scale,
            constraints.maxHeight / scale);
          return SingleChildScrollView(key: const ValueKey('code-result-scroll'),
            child: Center(child: SizedBox(width: width, height: height * scale,
              child: FittedBox(fit: BoxFit.fill, alignment: Alignment.topCenter,
                child: SizedBox(width: 375, height: height,
                  child: CustomPaint(key: const ValueKey('code-result-background'),
                    painter: _ReferenceBackground(dark: dark),
                    child: Stack(children: [
                      Positioned(left: 0, top: extraTop, width: 375, height: 812,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned(left: 7, top: 18, width: 44, height: 44,
                            child: _ReferenceTap(label: 'Back to scanner', onTap: onClose,
                              child: Center(child: _art('back', width: 20, height: 18,
                                color: Colors.white, directional: true)))),
                          Positioned(left: 16, top: 84, width: 343, height: 244,
                            child: _ReferenceCard(qrOnly: qrOnly, value: value,
                              formatLabel: formatLabel, onClose: onClose,
                              onOpen: onOpen, onCopy: onCopy, onSave: onSave)),
                          ..._promotion(c),
                        ])),
                    ]),
                  ),
                ),
              ),
            )),
          );
        }),
      ),
    );
  }

  List<Widget> _promotion(CodeResultColors c) => [
    _referenceText('TRY OUR OTHER APP', x: 20, baseline: 366, width: 260,
      size: 11, weight: FontWeight.w600, tracking: 1.4,
      color: Colors.white.withValues(alpha: c.dark ? .9 : .75)),
    Positioned(left: 297, top: 350, width: 62, height: 24,
      child: Container(decoration: BoxDecoration(
        color: c.dark ? c.badge : Colors.white.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          Positioned(left: 9.5, top: 8.5, width: 7, height: 7,
            child: DecoratedBox(decoration: const BoxDecoration(
              color: Color(0xFF7CFFB2), shape: BoxShape.circle))),
          _referenceText('FREE', x: 22, baseline: 16, width: 38, size: 11,
            weight: FontWeight.w700, tracking: .6),
        ]))),
    // Original Illustration viewBox (40,406,295,150), plus Promo_Body y=22.
    Positioned(left: 40, top: 428, width: 295, height: 150,
      child: _art('illustration', width: 295, height: 150)),
    for (final chip in [(62.0, 74.0, 'QR Code'), (144.0, 74.0, 'Barcode'),
      (226.0, 86.0, 'Wi‑Fi · vCard')])
      Positioned(left: chip.$1, top: 578, width: chip.$2, height: 26,
        child: Container(decoration: BoxDecoration(
          color: c.dark ? c.badge : Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(13)),
          child: Stack(children: [_referenceText(chip.$3,
            x: 0, baseline: 17, width: chip.$2, size: 12,
            weight: FontWeight.w600, align: TextAlign.center)]))),
    _referenceText('Make your own', x: 0, baseline: 634, width: 375,
      size: 23, weight: FontWeight.w800, align: TextAlign.center),
    _referenceText('QR & Barcodes', x: 0, baseline: 661, width: 375,
      size: 23, weight: FontWeight.w800, align: TextAlign.center),
    _referenceText('Create, customize and share in seconds.',
      x: 0, baseline: 683, width: 375, size: 13,
      color: Colors.white.withValues(alpha: c.dark ? .9 : .82), align: TextAlign.center),
    Positioned(left: 40, top: 698, width: 295, height: 52,
      child: _ReferenceSurface(key: const ValueKey('reference-store-button'),
        radius: 26, color: c.button,
        shadow: const Color(0xFF1B1F6B).withValues(alpha: .35),
        sigma: 8, offset: const Offset(0, 8),
        child: _ReferenceTap(label: 'Get it on Google Play', onTap: onPromotion,
          radius: 26, child: Stack(children: [
            Positioned(left: 52, top: 14, width: 22, height: 24,
              child: _art('play', width: 22, height: 24, color: c.dark ? c.action : null)),
            _referenceText('GET IT ON', x: 82, baseline: 21, width: 150, size: 10,
              weight: FontWeight.w600, tracking: .8,
              color: c.dark ? c.storeCaption : const Color(0xFF6B6B7B)),
            _referenceText('Google Play', x: 82, baseline: 39, width: 150, size: 17,
              weight: FontWeight.w700, color: c.storeText),
            Positioned(left: 253, top: 12, width: 28, height: 28,
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: c.dark ? const [Color(0xFF405BE0), Color(0xFF7941D1)]
                    : const [Color(0xFF4B68FF), Color(0xFF8A4DFF)])),
                child: Center(child: _art('next', width: 16, height: 14,
                  color: Colors.white, directional: true)))),
          ])))),
  ];
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.qrOnly, required this.value,
    required this.formatLabel, required this.onClose, required this.onOpen,
    required this.onCopy, required this.onSave});
  final bool qrOnly;
  final String value;
  final String? formatLabel;
  final VoidCallback onClose, onOpen, onCopy, onSave;

  @override
  Widget build(BuildContext context) {
    final c = CodeResultColors.of(context);
    final actionColor = c.dark ? c.action : const Color(0xFF4B68FF);
    final format = formatLabel ?? 'Barcode';
    final labelPainter = TextPainter(text: TextSpan(text: format,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: .6)),
      textDirection: TextDirection.ltr)..layout();
    final formatWidth = math.max(64.0, labelPainter.width + 16);
    labelPainter.dispose();
    return Container(key: const ValueKey('code-result-card'),
      // Foreground border avoids Container's implicit content padding.
      decoration: BoxDecoration(color: c.dark ? c.card : Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(28)),
      foregroundDecoration: BoxDecoration(border: Border.all(
        color: c.dark ? c.border : Colors.white.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(28)),
      child: Stack(clipBehavior: Clip.none, children: [
        _referenceText(qrOnly ? 'QR Code Detected' : 'Barcode Detected',
          x: 0, baseline: 39, width: 343, size: 18, weight: FontWeight.w600,
          align: TextAlign.center),
        Positioned(left: 295, top: 8, width: 44, height: 44,
          child: _ReferenceTap(label: 'Scan again', onTap: onClose,
            child: Center(child: Container(width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: c.dark ? c.badge : Colors.white.withValues(alpha: .25)),
              child: Center(child: _art('close', width: 14, height: 14, color: Colors.white)))))),
        Positioned(left: 16, top: 58, width: 311, height: 92,
          child: Container(key: const ValueKey('code-result-preview'),
            decoration: BoxDecoration(color: c.dark ? c.preview :
              const Color(0xFF1B1F6B).withValues(alpha: .35),
              borderRadius: BorderRadius.circular(20)))),
        if (qrOnly)
          Positioned(left: 36, top: 71, width: 271, height: 64,
            child: _ReferenceValue(value: value, size: 15, baseline: 15))
        else ...[
          Positioned(left: 32, top: 72, width: formatWidth, height: 24,
            child: Container(decoration: BoxDecoration(
              color: c.dark ? c.badge : Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12)),
              child: Stack(children: [_referenceText(format,
                key: const ValueKey('barcode-format'), x: 0, baseline: 16,
                width: formatWidth, size: 11, weight: FontWeight.w700,
                tracking: .6, align: TextAlign.center)]))),
          Positioned(left: 246, top: 72, width: 64, height: 30,
            child: _art('mini_barcode', width: 64, height: 30)),
          Positioned(left: 32, top: 108, width: 279, height: 34,
            child: _ReferenceValue(value: value, size: 22, baseline: 22,
              tracking: 2, weight: FontWeight.w600)),
        ],
        for (final action in [
          (16.0, qrOnly ? 'Open' : 'Search', qrOnly ? 'open' : 'search', onOpen),
          (123.5, 'Copy', 'copy', onCopy), (231.0, 'Save', 'save', onSave),
        ])
          Positioned(left: action.$1, top: 172, width: 96, height: 44,
            child: _ReferenceSurface(key: ValueKey('reference-${action.$3}-button'),
              radius: 12, color: c.button,
              shadow: Colors.black.withValues(alpha: .12),
              sigma: 3, offset: const Offset(0, 2),
              child: _ReferenceTap(label: action.$2, onTap: action.$4, radius: 12,
                child: Stack(children: [
                  if (action.$3 == 'open')
                    Positioned(left: 13, top: 13, width: 18, height: 18,
                      child: _art('open', width: 18, height: 18, color: actionColor)),
                  if (action.$3 == 'search')
                    Positioned(left: 12, top: 12, width: 19, height: 19,
                      child: _art('search', width: 19, height: 19, color: actionColor)),
                  if (action.$3 == 'copy')
                    Positioned(left: 12.5, top: 11, width: 16, height: 16,
                      child: _art('copy', width: 16, height: 16, color: actionColor)),
                  if (action.$3 == 'save')
                    Positioned(left: 20, top: 13, width: 16, height: 20,
                      child: _art('save', width: 16, height: 20, color: actionColor)),
                  _referenceText(action.$2, x: action.$3 == 'copy' ? 35.5 :
                    action.$3 == 'save' ? 41 : 39, baseline: 27.5,
                    width: 57, size: 15, weight: FontWeight.w600, color: actionColor),
                ])))),
      ]),
    );
  }
}

class _ReferenceValue extends StatelessWidget {
  const _ReferenceValue({required this.value, required this.size,
    required this.baseline, this.tracking = 0, this.weight = FontWeight.w400});
  final String value;
  final double size, baseline, tracking;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => ClipRect(child: SingleChildScrollView(
    key: const ValueKey('code-result-payload-scroll'),
    child: Baseline(baseline: baseline, baselineType: TextBaseline.alphabetic,
      child: SelectableText(value, textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: size,
          height: 1.3, fontWeight: weight, letterSpacing: tracking))),
  ));
}

Widget _referenceText(String text, {Key? key, required double x,
  required double baseline, required double width, required double size,
  FontWeight weight = FontWeight.w400, Color color = Colors.white,
  double tracking = 0, TextAlign align = TextAlign.left}) =>
  Positioned(left: x, top: baseline - size, width: width,
    child: Baseline(baseline: size, baselineType: TextBaseline.alphabetic,
      child: AppText(text, key: key, textAlign: align, textScaler: TextScaler.noScaling,
        maxLines: 1, softWrap: false, overflow: TextOverflow.visible,
        style: TextStyle(fontFamily: 'Inter', color: color, fontSize: size,
          fontWeight: weight, height: 1, letterSpacing: tracking))));

class _ReferenceTap extends StatelessWidget {
  const _ReferenceTap({required this.label, required this.onTap,
    required this.child, this.radius = 22});
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => Semantics(button: true, label: context.tr(label),
    excludeSemantics: true, child: Tooltip(message: context.tr(label),
      child: Material(type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius),
          child: child))));
}

class _ReferenceSurface extends StatelessWidget {
  const _ReferenceSurface({super.key, required this.radius, required this.color,
    required this.shadow, required this.sigma, required this.offset, required this.child});
  final double radius, sigma;
  final Color color, shadow;
  final Offset offset;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ReferenceShadow(radius, color, shadow, sigma, offset), child: child);
}

class _ReferenceShadow extends CustomPainter {
  const _ReferenceShadow(this.radius, this.color, this.shadow, this.sigma, this.offset);
  final double radius, sigma;
  final Color color, shadow;
  final Offset offset;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(shape.shift(offset), Paint()..color = shadow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
    canvas.drawRRect(shape, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_ReferenceShadow old) => old.radius != radius ||
    old.color != color || old.shadow != shadow || old.sigma != sigma || old.offset != offset;
}

class _ReferenceBackground extends CustomPainter {
  const _ReferenceBackground({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, .55, 1],
      colors: dark ? const [Color(0xFF111C38), Color(0xFF1B2149), Color(0xFF312049)]
        : const [Color(0xFF4B68FF), Color(0xFF5B5BFF), Color(0xFF8A4DFF)],
    ).createShader(const Rect.fromLTWH(0, 0, 375, 812)));
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 0, 375, 460));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 375, 460), Paint()..shader = RadialGradient(
      colors: [Colors.white.withValues(alpha: dark ? .04 : .28), Colors.transparent],
    ).createShader(Rect.fromCircle(center: const Offset(300, 0), radius: 320)));
    canvas.restore();
    for (final ring in [(360.0, 60.0, 90.0, .12), (360.0, 60.0, 135.0, .08),
      (10.0, 760.0, 110.0, .1), (10.0, 760.0, 160.0, .07)]) {
      canvas.drawCircle(Offset(ring.$1, ring.$2), ring.$3, Paint()
        ..color = Colors.white.withValues(alpha: dark ? .035 : ring.$4)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override
  bool shouldRepaint(_ReferenceBackground old) => old.dark != dark;
}
