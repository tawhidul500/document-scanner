import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/app_preferences.dart';
import 'package:pdf_scanner/features/settings/settings_screen.dart';
import 'package:pdf_scanner/main.dart';
import 'package:pdf_scanner/theme/app_theme.dart';
import 'package:pdf_scanner/widgets/reference_navigation.dart';
import 'package:pdf_scanner/widgets/reference_toolbar_surface.dart';
import 'support/pump_until.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AppPreferences preferences;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('appearance_test_');
    preferences = AppPreferences(file: File('${directory.path}/preferences.json'));
  });
  tearDown(() async {
    preferences.dispose();
    await directory.delete(recursive: true);
  });

  test('all modes persist and old/unknown preferences use System Default', () async {
    for (final mode in ThemeMode.values) {
      await preferences.update(themeMode: mode);
      final restored = AppPreferences(file: preferences.file);
      await restored.load();
      expect(restored.themeMode, mode);
      restored.dispose();
    }
    for (final json in ['{"beep":false}', '{"themeMode":"unknown"}']) {
      await preferences.file!.writeAsString(json);
      final restored = AppPreferences(file: preferences.file);
      await restored.load();
      expect(restored.themeMode, ThemeMode.system);
      restored.dispose();
    }
  });

  test('queued theme and feedback changes preserve one another', () async {
    await Future.wait([
      preferences.update(themeMode: ThemeMode.dark),
      preferences.update(beep: false),
      preferences.update(vibration: false, language: 'bn'),
    ]);
    final restored = AppPreferences(file: preferences.file);
    await restored.load();
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.beep, isFalse);
    expect(restored.vibration, isFalse);
    expect(restored.language, 'bn');
    restored.dispose();
  });

  test('failed save retains the current appearance', () async {
    // A regular file cannot serve as the parent directory of a preferences file.
    final blocker = await File('${directory.path}/blocked').writeAsString('file');
    preferences.file = File('${blocker.path}/settings.json');
    await expectLater(preferences.update(themeMode: ThemeMode.dark),
      throwsA(isA<FileSystemException>()));
    expect(preferences.themeMode, ThemeMode.system);
  });

  testWidgets('System follows device changes; explicit modes stay fixed', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(ScannerApp(preferences: preferences,
      home: Builder(builder: (context) => Scaffold(
        body: Text(Theme.of(context).brightness.name)))));
    expect(find.text('light'), findsOneWidget);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
    await tester.runAsync(() => preferences.update(themeMode: ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('light'), findsOneWidget);
    await tester.runAsync(() => preferences.update(themeMode: ThemeMode.dark));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
    await tester.runAsync(() => preferences.update(themeMode: ThemeMode.system));
    await tester.pumpAndSettle();
    expect(find.text('light'), findsOneWidget);
  });

  testWidgets('theme cards save the choice and update the current route', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScannerApp(preferences: preferences,
      home: ThemeScreen(preferences: preferences)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('theme-dark')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await pumpUntil(tester, () => preferences.themeMode == ThemeMode.dark,
        reason: 'the dark theme preference to be saved');
    await tester.pumpAndSettle();
    expect(preferences.themeMode, ThemeMode.dark);
    final context = tester.element(find.byKey(const ValueKey('theme-dark')));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('Choose app appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme choices fit small screens and enlarged text in both modes', (tester) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 375.0, 430.0]) {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      for (final dark in [false, true]) {
        for (final factor in [1.0, 2.0]) {
          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppThemes.dark : AppThemes.light,
            home: Builder(builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(factor)),
              child: ThemeScreen(preferences: preferences)))));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('theme-dark')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
            reason: 'width=$width, dark=$dark, textScale=$factor');
        }
      }
    }
  });

  testWidgets('navigation and toolbar share the active surface palette', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(MaterialApp(theme: dark ? AppThemes.dark : AppThemes.light,
        home: const Scaffold(body: ReferenceToolbarSurface(child: Text('Toolbar')),
          bottomNavigationBar: ReferenceHomeNavigation())));
      await tester.pumpAndSettle();
      final toolbar = tester.widget<DecoratedBox>(find.descendant(
        of: find.byType(ReferenceToolbarSurface), matching: find.byType(DecoratedBox)).first);
      expect((toolbar.decoration as BoxDecoration).color, AppPalette(dark).surface);
      final assetNames = tester.widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
      expect(assetNames, contains(dark ? 'assets/home/exact_navigation_dark.png'
        : 'assets/home/exact_navigation.png'));
      expect(tester.takeException(), isNull);
    }
  });
}
