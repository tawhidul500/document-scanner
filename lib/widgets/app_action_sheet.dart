import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_action_icon.dart';

Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  required Widget title,
  required List<Widget> Function(BuildContext) actions,
  String closeLabel = 'Close',
  double maxHeightFraction = .85,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppPalette.of(context).surface,
  clipBehavior: Clip.antiAlias,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheetContext) => AppActionSheet(
    title: title,
    closeLabel: closeLabel,
    maxHeightFraction: maxHeightFraction,
    onClose: () => Navigator.pop(sheetContext),
    children: actions(sheetContext),
  ),
);

/// Keeps the close target outside the title's layout and above scrolling rows.
class AppActionSheet extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
    this.closeLabel = 'Close',
    this.maxHeightFraction = .85,
  });

  final Widget title;
  final VoidCallback onClose;
  final List<Widget> children;
  final String closeLabel;
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        header: true,
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.of(context).text,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          child: title,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const ValueKey('sheet-close-button'),
                      tooltip: context.tr(closeLabel),
                      onPressed: onClose,
                      icon: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.of(context).closeSurface,
                          shape: BoxShape.circle,
                        ),
                        child: AppActionIcon('Close', size: 10,
                            color: AppPalette.of(context).text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppPalette.of(context).outline),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppMenuAction extends StatelessWidget {
  const AppMenuAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = label == 'Delete' ? palette.danger : palette.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minTileHeight: 48,
          minLeadingWidth: 24,
          horizontalTitleGap: 24,
          leading: AppActionIcon(label, fallback: icon, color: color),
          title: AppText(label, style: TextStyle(fontSize: 16, color: color)),
          subtitle: subtitle,
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 72),
          child: Divider(height: 1, color: palette.outline),
        ),
      ],
    );
  }
}
