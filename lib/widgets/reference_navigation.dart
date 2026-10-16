import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Compact reference navigation with a raised camera and a real curved cutout.
/// Native controls keep labels sharp and respect locale and text scaling.
class ReferenceHomeNavigation extends StatelessWidget {
  const ReferenceHomeNavigation({super.key, this.cameraKey,
    this.cameraVisible = true, this.settingsSelected = false,
    this.homeSelected = true, this.onScan, this.onHome, this.onSettings});
  final GlobalKey? cameraKey;
  final bool cameraVisible, settingsSelected, homeSelected;
  final VoidCallback? onScan, onHome, onSettings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final extra = (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(0.0, 40.0);
    return SizedBox(
      height: 100 + bottom + extra,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(
          key: const ValueKey('navigation-surface'),
          painter: NavigationSurfacePainter(p.surface, p.dark, p.background),
        )),
        PositionedDirectional(start: 0, top: 36, bottom: bottom + 4,
          width: MediaQuery.sizeOf(context).width * .44,
          child: _tab(context, 'Home', Icons.home_rounded, homeSelected, onHome)),
        PositionedDirectional(end: 0, top: 36, bottom: bottom + 4,
          width: MediaQuery.sizeOf(context).width * .44,
          child: _tab(context, 'Settings', Icons.settings_outlined, settingsSelected, onSettings)),
        if (cameraVisible) Positioned(top: 0, left: 0, right: 0,
          child: Center(child: Tooltip(message: context.tr('Scan'),
            child: Semantics(button: true, label: context.tr('Scan'),
              child: Material(
                color: p.dark ? const Color(0xFF3177DE) : const Color(0xFF205BBF),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(key: cameraKey, onTap: onScan,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(width: 52, height: 52,
                    child: Icon(Icons.camera_alt_rounded, size: 30, color: Colors.white)),
                ),
              ),
            ),
          )),
        ),
      ]),
    );
  }

  Widget _tab(BuildContext context, String label, IconData icon,
      bool selected, VoidCallback? onTap) {
    final p = AppPalette.of(context);
    final color = selected ? p.primary : p.dark ? p.text : const Color(0xFF141414);
    return Tooltip(message: context.tr(label),
      child: Semantics(button: true, selected: selected,
        child: Material(color: Colors.transparent,
          child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 27, color: color),
              const SizedBox(height: 5),
              AppText(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.2, color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

class NavigationSurfacePainter extends CustomPainter {
  const NavigationSurfacePainter(this.color, this.dark, this.background);
  final Color color, background;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final c = size.width / 2;
    final path = Path()
      ..moveTo(0, 26)
      ..lineTo(c - 50, 26)
      ..cubicTo(c - 36, 26, c - 35, 30, c - 32, 40)
      ..cubicTo(c - 23, 68, c + 23, 68, c + 32, 40)
      ..cubicTo(c + 35, 30, c + 36, 26, c + 50, 26)
      ..lineTo(size.width, 26)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()
      ..color = Colors.black.withValues(alpha: dark ? .30 : .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(NavigationSurfacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dark != dark ||
      oldDelegate.background != background;
}

/// Returning to the root before scanning reuses the existing scan workflow.
void scanFromNavigation(BuildContext context, VoidCallback? onScan) {
  if (onScan == null) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
  WidgetsBinding.instance.addPostFrameCallback((_) => onScan());
}
