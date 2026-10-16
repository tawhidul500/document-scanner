import 'package:pdf_scanner/data/app_preferences.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';
import 'package:pdf_scanner/features/splash/splash_screen.dart';
import 'package:pdf_scanner/main.dart';

void main() {
  testWidgets('startup waits for work, not the six-second animation', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('startup_test_');
    final store = DocumentStore(dir);
    final preferences = AppPreferences(file: File('${dir.path}/preferences.json'));
    await tester.runAsync(() => preferences.completeLanguageSetup('en'));
    await tester.runAsync(store.load);
    final completion = Completer<DocumentStore>();
    ValueChanged<double>? report;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          preferences: preferences,
          loader: (callback) {
            report = callback;
            return completion.future;
          },
        ),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('startup-progress')),
          )
          .properties.value,
      isNull,
    );
    for (var i = 0; i < 100 && report == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    report!(0.4);
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('startup-progress')),
          )
          .properties.value,
      '40%',
    );
    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(HomeScreen), findsNothing);
    completion.complete(store);
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('failed startup offers retry and fast success opens Home', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('startup_retry_');
    final store = DocumentStore(dir);
    final preferences = AppPreferences(file: File('${dir.path}/preferences.json'));
    await tester.runAsync(() => preferences.completeLanguageSetup('en'));
    await tester.runAsync(store.load);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          preferences: preferences,
          loader: (_) async {
            if (attempts++ == 0) throw const FileSystemException('Unavailable');
            return store;
          },
        ),
      ),
    );
    for (var i = 0; i < 100 && find.text('Try again').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 100 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets('supplied animation and footer fit a small phone with safe insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(progress: 0.5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final rect = tester.getRect(find.byKey(const ValueKey('opening-artboard')));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(568));
    // The upload's loading caption ends at y=737 in its 812-pixel artboard.
    expect(rect.top + rect.height * 737 / 812, lessThanOrEqualTo(534));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all languages use the new animation and honor reduced motion',
      (tester) async {
    for (final language in AppStrings.languages) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppThemes.dark : AppThemes.light,
          locale: Locale(language),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SplashScreen(progress: .5),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        final player = tester.widget<LottieBuilder>(
            find.byKey(const ValueKey('opening-animation')));
        expect(player.animate, isFalse);
        expect(player.repeat, isTrue);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        if (language != 'en') {
          expect(find.text(AppStrings.translate('Document Scanner', language)),
              findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
