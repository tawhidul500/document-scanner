import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared visual language for all empty document lists and search results.
class ScanEmptyState extends StatelessWidget {
  const ScanEmptyState({super.key, this.search = false, this.title, this.message});
  final bool search;
  final String? title, message;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(themedAsset(context, 'assets/home/exact_empty_illustration.png'),
        width: 126, height: 123, excludeFromSemantics: true),
      const SizedBox(height: 7),
      AppText(title ?? (search ? 'No matching files' : 'No files here yet'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, height: 24 / 17,
          fontWeight: FontWeight.w700, color: AppPalette.of(context).text)),
      const SizedBox(height: 1),
      AppText(message ?? (search ? 'Try another file name.' :
        'Tap the camera button below to scan\nyour first document.'),
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 13, height: 18 / 13)),
    ],
  );
}
