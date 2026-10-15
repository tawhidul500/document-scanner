import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/home/camera_action_menu.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ValueChanged<CameraAction?> result,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 813);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result(
                  await showCameraActionMenu(
                    context,
                    const Rect.fromLTWH(155.5, 711, 64, 64),
                  ),
                );
              },
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('five actions align with supplied design and return one choice', (
    tester,
  ) async {
    CameraAction? selected;
    await mount(tester, (action) => selected = action);
    for (final label in CameraActionMenu.labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.getRect(find.byKey(const ValueKey('camera-menu-document'))),
      const Rect.fromLTWH(91, 405, 194, 53),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('camera-menu-close'))),
      const Offset(188, 746),
    );
    await tester.tap(find.text('Import PDF'));
    await tester.pumpAndSettle();
    expect(selected, CameraAction.importPdf);
    expect(find.byType(CameraActionMenu), findsNothing);
  });

  testWidgets('close and outside tap dismiss without starting an action', (
    tester,
  ) async {
    CameraAction? selected;
    await mount(tester, (action) => selected = action);
    await tester.tap(find.byKey(const ValueKey('camera-menu-close')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(CameraActionMenu), findsNothing);
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(15, 180));
    await tester.pumpAndSettle();
    expect(find.byType(CameraActionMenu), findsNothing);
    expect(selected, isNull);
  });

  testWidgets('system Back closes menu', (tester) async {
    await mount(tester, (_) {});
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CameraActionMenu), findsNothing);
  });
}
