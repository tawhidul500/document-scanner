import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CameraAction { document, idCard, qr, barcode, importPdf }

Future<CameraAction?> showCameraActionMenu(BuildContext context, Rect anchor) {
  return showGeneralDialog<CameraAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close scan options',
    barrierColor: const Color(0x700C0C0C),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        CameraActionMenu(anchor: anchor),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class CameraActionMenu extends StatelessWidget {
  const CameraActionMenu({super.key, required this.anchor});
  final Rect anchor;
  static const labels = [
    'Documents',
    'Id Card',
    'QR Code',
    'Bar Code',
    'Import PDF',
  ];
  static const colors = [
    [Color(0xFF2F7BEA), Color(0xFF0060EB)],
    [Color(0xFF22B35E), Color(0xFF00933D)],
    [Color(0xFF8B4BEA), Color(0xFF5823A6)],
    [Color(0xFFF5921E), Color(0xFFDC7906)],
    [Color(0xFFFF383C), Color(0xFFB5171A)],
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textFactor = media.textScaler.scale(16) / 16;
    final rowHeight = math.max(
      53.0,
      textFactor > 1.6 ? 20 + 41.6 * textFactor : 28 + 22 * textFactor,
    );
    final double menuWidth = math.min<double>(
      media.size.width - 32,
      math.max(194.0, 194.0 * math.min(textFactor, 1.6)),
    );
    final bottom = math.max(
      media.viewPadding.bottom + 16,
      media.size.height - anchor.center.dy - 30,
    );
    final available = math.max(
      0.0,
      media.size.height - media.viewPadding.top - 8 - bottom,
    );
    final height = math.min(5 * rowHeight + 40 + 9 + 54, available);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: 'Scan options',
            child: Stack(
              children: [
                Positioned(
                  left: (media.size.width - menuWidth) / 2 + 0.5,
                  bottom: bottom,
                  width: menuWidth,
                  height: height,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final action in CameraAction.values) ...[
                            if (action.index > 0) const SizedBox(height: 10),
                            Container(
                              key: ValueKey('camera-menu-${action.name}'),
                              height: rowHeight,
                              width: menuWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  rowHeight / 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x15000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  rowHeight / 2,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: colors[action.index],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      rowHeight / 2,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () =>
                                        Navigator.of(context).pop(action),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 35,
                                        right: 20,
                                      ),
                                      child: Row(
                                        children: [
                                          Image.asset(
                                            'assets/camera_menu/${action.name}.png',
                                            width: 27,
                                            height: 28,
                                            excludeFromSemantics: true,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              labels[action.index],
                                              maxLines: textFactor > 1.6
                                                  ? 2
                                                  : 1,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          SizedBox(
                            width: 54,
                            height: 54,
                            child: Material(
                              color: const Color(0xFF1C59C1),
                              shape: const CircleBorder(),
                              elevation: 3,
                              shadowColor: const Color(0x55000000),
                              child: IconButton(
                                key: const ValueKey('camera-menu-close'),
                                tooltip: 'Close scan options',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
