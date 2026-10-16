import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Artwork is split into components from the supplied SVG, at 4x density.
/// Hit regions remain native controls; system bars remain OS-owned.
class ReferenceHomeNavigation extends StatelessWidget {
  const ReferenceHomeNavigation({super.key, this.cameraKey, this.cameraVisible = true, this.settingsSelected = false, this.homeSelected = true,
    this.onScan, this.onHome, this.onSettings});
  final GlobalKey? cameraKey;
  final bool cameraVisible;
  final bool settingsSelected, homeSelected;
  final VoidCallback? onScan, onHome, onSettings;

  Widget target(BuildContext context, String label, VoidCallback? action, {Key? key}) =>
    Tooltip(message: context.tr(label), child: Semantics(button: true, label: context.tr(label),
      child: Material(color: Colors.transparent,
        child: InkWell(key: key, onTap: action,
          borderRadius: BorderRadius.circular(30)))));

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppPalette.of(context).surface,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: AspectRatio(aspectRatio: 375 / 116,
        child: LayoutBuilder(builder: (context, constraints) {
          final scale = constraints.maxWidth / 375;
          return Stack(children: [
            Positioned.fill(child: IgnorePointer(child: Transform.flip(
              flipX: !context.englishLayout && Directionality.of(context) == TextDirection.rtl,
              child: ClipPath(
              key: const ValueKey('navigation-artwork'),
              clipper: !context.englishLayout
                  ? _LocalizedNavigationArtwork(hideCamera: !cameraVisible)
                  : cameraVisible ? null : const _HideCameraArtwork(),
              child: Image.asset(
              themedAsset(context, 'assets/home/exact_navigation${settingsSelected ? '_settings' : homeSelected ? '' : '_neutral'}.png'), fit: BoxFit.fill,
              excludeFromSemantics: true))))),
            if (!context.englishLayout)
              for (final tab in [(true, 'Home', homeSelected), (false, 'Settings', settingsSelected)])
                PositionedDirectional(start: tab.$1 ? 5 * scale : null,
                  end: tab.$1 ? null : 11 * scale, bottom: 8 * scale,
                  width: 115 * scale, height: 22 * scale,
                  child: IgnorePointer(child: Center(child: AppText(tab.$2,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12 * scale,
                      color: tab.$3 ? AppPalette.of(context).primary : AppPalette.of(context).text))))),
            if (cameraVisible) Positioned(left: 152 * scale, top: 13 * scale,
              width: 72 * scale, height: 72 * scale,
              child: target(context, 'Scan', onScan, key: cameraKey)),
            PositionedDirectional(start: 25 * scale, top: 56 * scale,
              width: 74 * scale, height: 60 * scale,
              child: Semantics(selected: homeSelected, child: target(context, 'Home', onHome))),
            PositionedDirectional(end: 31 * scale, top: 56 * scale,
              width: 74 * scale, height: 60 * scale,
              child: Semantics(selected: settingsSelected, child: target(context, 'Settings', onSettings))),
          ]);
        }),
      ),
    ),
  );
}

/// Retains the supplied icons while removing the English lettering below them.
class _LocalizedNavigationArtwork extends CustomClipper<Path> {
  const _LocalizedNavigationArtwork({required this.hideCamera});
  final bool hideCamera;
  @override
  Path getClip(Size size) {
    final scale = size.width / 375;
    if (!hideCamera) return Path()..addRect(Rect.fromLTWH(0, 0, size.width, 90 * scale));
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, 130 * scale, 90 * scale))
      ..addRect(Rect.fromLTRB(246 * scale, 0, size.width, 90 * scale));
  }
  @override
  bool shouldReclip(_LocalizedNavigationArtwork old) => old.hideCamera != hideCamera;
}

/// The navigation bitmap contains the camera, its ring, and its shadow.
/// Clip the entire centre strip while the menu supplies its own close button.
/// The white navigation surface remains underneath, with both side tabs intact.
class _HideCameraArtwork extends CustomClipper<Path> {
  const _HideCameraArtwork();

  @override
  Path getClip(Size size) {
    final scale = size.width / 375;
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, 130 * scale, size.height))
      ..addRect(Rect.fromLTRB(246 * scale, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(_HideCameraArtwork oldClipper) => false;
}


/// Returning to the root before scanning reuses the existing scan workflow.
void scanFromNavigation(BuildContext context, VoidCallback? onScan) {
  if (onScan == null) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
  WidgetsBinding.instance.addPostFrameCallback((_) => onScan());
}
