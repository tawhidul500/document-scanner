import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Original reference paths rendered at 4x with inherited SVG fill preserved.
/// Resolve appearance at build time so system theme changes update every icon.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => Image.asset(
    themedAsset(context, 'assets/theme/$name.png'),
    width: 37.108,
    height: 37.108,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
