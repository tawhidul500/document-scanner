import 'package:flutter/material.dart';

/// The original supplied action artwork, shared by menus and toolbars.
/// Tinting the alpha mask preserves its geometry in both app appearances.
class AppActionIcon extends StatelessWidget {
  const AppActionIcon(this.action, {
    super.key,
    this.fallback = Icons.description_outlined,
    this.size = 24,
    this.color,
  });

  final String action;
  final IconData fallback;
  final double size;
  final Color? color;

  static const artwork = <String, String>{
    'Close': 'close',
    'Rename': 'rename',
    'Edit': 'edit',
    'Open document actions': 'edit',
    'Sign': 'sign',
    'OCR': 'ocr',
    'Share': 'share',
    'Download': 'download',
    'Export': 'download',
    'Move': 'move',
    'Merge': 'merge',
    'Delete': 'delete',
  };

  @override
  Widget build(BuildContext context) {
    final asset = artwork[action];
    if (asset == null) return Icon(fallback, size: size, color: color);
    final theme = IconTheme.of(context);
    final tint = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return Opacity(
      opacity: color == null ? (theme.opacity ?? 1) : 1,
      child: Image.asset(
        'assets/actions/$asset.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: tint,
        excludeFromSemantics: true,
      ),
    );
  }
}
