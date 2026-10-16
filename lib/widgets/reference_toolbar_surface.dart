import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReferenceToolbarSurface extends StatelessWidget {
  const ReferenceToolbarSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      boxShadow: [BoxShadow(color: Color(0x12000000),
        blurRadius: 21, offset: Offset(0, -1))],
    ),
    child: child,
  );
}
