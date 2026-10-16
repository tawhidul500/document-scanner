import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/app_preferences.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';
import 'package:pdf_scanner/features/onboarding/language_setup_screen.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/main.dart';

void main() {
  late Directory directory;
  late AppPreferences preferences;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('first_language_');
    preferences = AppPreferences(
      file: File('${directory.path}/preferences.json'),
    );
  });

  tearDown(() async {
    preferences.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      if (target.evaluate().isNotEmpty) return;
    }

    fail('Did not reach $target');
  }

  Widget app() => ScannerApp(
        preferences: preferences,
        home: StartupScreen(
          preferences: preferences,
          loader: (_) async {
            final store = DocumentStore(
              Directory('${directory.path}/documents'),
            );
            await store.load();
            return store;
          },
        ),
      );

  final next = find.byKey(const ValueKey('first-language-next'));

  testWidgets(
    'first launch requires selection and Next, then future launches skip it',
    (tester) async {
      await tester.pumpWidget(app());
      await waitFor(tester, find.byType(LanguageSetupScreen));

      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('first-language-bn')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.translate('Next', 'bn')),
        findsOneWidget,
      );
      expect(preferences.language, 'en');
      expect(preferences.languageSetupComplete, isFalse);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);

      await tester.tap(next);
      await waitFor(tester, find.byType(HomeScreen));

      expect(preferences.language, 'bn');
      expect(preferences.languageSetupComplete, isTrue);
      expect(find.byType(LanguageSetupScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());

      final savedFile = preferences.file;
      preferences.dispose();
      preferences = AppPreferences(file: savedFile);

      await tester.pumpWidget(app());
      await waitFor(tester, find.byType(HomeScreen));

      expect(find.byType(LanguageSetupScreen), findsNothing);
      expect(preferences.language, 'bn');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'leaving before Next keeps first-launch setup pending',
    (tester) async {
      await tester.pumpWidget(app());
      await waitFor(tester, find.byType(LanguageSetupScreen));

      await tester.tap(
        find.byKey(const ValueKey('first-language-bn')),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await waitFor(tester, find.byType(LanguageSetupScreen));

      expect(preferences.languageSetupComplete, isFalse);
      expect(preferences.language, 'en');
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'save failure stays on language setup and permits retry',
    (tester) async {
      await tester.pumpWidget(app());
      await waitFor(tester, find.byType(LanguageSetupScreen));

      await tester.tap(
        find.byKey(const ValueKey('first-language-en')),
      );
      await tester.pump();

      final goodFile = preferences.file;
      final blocker = File('${directory.path}/blocked')
        ..writeAsStringSync('file');

      preferences.file = File('${blocker.path}/settings.json');

      await tester.tap(next);
      await waitFor(
        tester,
        find.text('Could not save language. Please try again.'),
      );

      expect(find.byType(HomeScreen), findsNothing);
      expect(preferences.languageSetupComplete, isFalse);

      preferences.file = goodFile;

      await tester.tap(next);
      await waitFor(tester, find.byType(HomeScreen));

      expect(preferences.languageSetupComplete, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Arabic and large text fit with Next visible in both appearances',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        preferences.themeMode = mode;

        await tester.pumpWidget(
          ScannerApp(
            preferences: preferences,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                ),
                child: LanguageSetupScreen(
                  preferences: preferences,
                ),
              ),
            ),
          ),
        );

        final languageList = find.descendant(
          of: find.byKey(
            const ValueKey('first-launch-languages'),
          ),
          matching: find.byType(Scrollable),
        );

        final arabicOption = find.byKey(
          const ValueKey('first-language-ar'),
        );

        await tester.scrollUntilVisible(
          arabicOption,
          180,
          scrollable: languageList,
        );
        await tester.pumpAndSettle();

        // Center the option so the Next button cannot cover its tap target.
        await Scrollable.ensureVisible(
          tester.element(arabicOption),
          alignment: 0.5,
          duration: Duration.zero,
        );
        await tester.pumpAndSettle();

        await tester.tap(arabicOption);
        await tester.pumpAndSettle();

        expect(
          Directionality.of(tester.element(next)),
          TextDirection.rtl,
        );
        expect(
          tester.getRect(next).bottom,
          lessThanOrEqualTo(568),
        );

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('first-language-pt')),
          180,
          scrollable: languageList,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
