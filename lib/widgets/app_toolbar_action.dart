import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_action_icon.dart';

/// Consistent icon size, caption, and state colors for bottom action bars.
class AppToolbarAction extends StatelessWidget {
  const AppToolbarAction({
    super.key,
    this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.primary = false,
    this.hint,
  });
  final Key? buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected, primary;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: context.tr(hint ?? label),
      child: TextButton(
        key: buttonKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected || primary ? palette.primary : palette.text,
          disabledForegroundColor: palette.disabled,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppActionIcon(label, fallback: icon),
            const SizedBox(height: 6),
            AppText(label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
