import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:pdf_scanner/widgets/app_action_sheet.dart';
import 'package:pdf_scanner/widgets/app_toolbar_action.dart';

void main() {
  for (final title in ['Document Files', 'ID Card Options']) {
    testWidgets('$title keeps close clear of the title and above scrolling rows',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final width in [320.0, 375.0, 430.0, 800.0]) {
        tester.view.physicalSize = Size(width, 812);
        for (final dark in [false, true]) {
          for (final language in ['en', 'ar']) {
            for (final scale in [1.0, 2.0]) {
              await tester.pumpWidget(MaterialApp(
                theme: dark ? AppThemes.dark : AppThemes.light,
                locale: Locale(language),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: Builder(builder: (context) => TextButton(
                  onPressed: () => showAppActionSheet<void>(
                    context: context,
                    title: AppText(title),
                    actions: (_) => List.generate(20, (index) => AppMenuAction(
                      label: 'Rename', icon: Icons.edit_outlined, onTap: () {},
                    )),
                  ),
                  child: const Text('Show sheet'),
                ))),
              ));
              await tester.tap(find.text('Show sheet'));
              await tester.pumpAndSettle();
              final header = find.text(AppStrings.translate(title, language));
              final close = find.byKey(const ValueKey('sheet-close-button'));
              final titleRect = tester.getRect(header);
              final closeRect = tester.getRect(close);
              final sheetRect = tester.getRect(find.byType(AppActionSheet));
              expect(titleRect.overlaps(closeRect), isFalse);
              expect(titleRect.center.dx, closeTo(sheetRect.center.dx, .01));
              expect(closeRect.width, 48);
              expect(closeRect.height, 48);
              if (language == 'ar') {
                expect(closeRect.left, closeTo(sheetRect.left, .01));
              } else {
                expect(closeRect.right, closeTo(sheetRect.right, .01));
              }
              await tester.drag(find.byType(SingleChildScrollView),
                  const Offset(0, -450));
              await tester.pumpAndSettle();
              expect(tester.getRect(close), closeRect);
              await tester.tap(close);
              await tester.pumpAndSettle();
              expect(find.byType(AppActionSheet), findsNothing);
              expect(tester.takeException(), isNull,
                  reason: '$title, $width, dark=$dark, $language, scale=$scale');
            }
          }
        }
      }
    });
  }

  testWidgets('toolbar artwork follows selected and disabled theme colors',
      (tester) async {
    for (final dark in [false, true]) {
      final palette = AppPalette(dark);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppThemes.dark : AppThemes.light,
        home: Scaffold(body: Row(children: [
          Expanded(child: AppToolbarAction(label: 'Share',
              icon: Icons.share_outlined, selected: true, onPressed: () {})),
          const Expanded(child: AppToolbarAction(label: 'Download',
              icon: Icons.file_download_outlined, onPressed: null)),
        ])),
      ));
      await tester.pumpAndSettle();
      final artwork = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(artwork[0].color, palette.primary);
      expect(artwork[1].color, palette.disabled);
      expect(tester.takeException(), isNull);
    }
  });
}
