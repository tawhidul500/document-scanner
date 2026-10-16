import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/app_preferences.dart';
import 'package:pdf_scanner/data/document_store.dart';
import 'package:pdf_scanner/features/home/home_screen.dart';
import 'package:pdf_scanner/features/scan/code_result_screen.dart';
import 'package:pdf_scanner/l10n/app_catalog.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:pdf_scanner/main.dart';

void main() {
  test('every message has all eight translations and matching placeholders', () {
    expect(AppStrings.languages, AppPreferences.languages);
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final entry in appCatalog.entries) {
      expect(entry.value, hasLength(8), reason: entry.key);
      final expected = placeholder.allMatches(entry.key).map((m) => m[1]).toSet();
      for (final text in entry.value) {
        expect(text.trim(), isNotEmpty, reason: entry.key);
        expect(placeholder.allMatches(text).map((m) => m[1]).toSet(), expected,
            reason: entry.key);
      }
    }
    const filename = 'Share {count} العربية.pdf';
    final message = AppStrings.translate('Delete {filename} from this app? Exported copies will remain.',
        'fr', {'filename': filename});
    expect(message, contains(filename));
    expect(AppStrings.translate('Save', 'unknown'), 'Save');
  });

  late Directory directory;
  late DocumentStore store;
  late AppPreferences preferences;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_language_test_');
    store = DocumentStore(Directory('${directory.path}/documents'));
    await store.load();
    await store.addBytes(utf8.encode('Original scan: Save Share {count}'),
        ScanKind.qr, 'txt', name: 'Share');
    preferences = AppPreferences(file: File('${directory.path}/preferences.json'));
  });
  tearDown(() async {
    store.dispose();
    preferences.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 350));
        return;
      }
    }
    fail('Expected localized widget: $finder');
  }

  testWidgets('existing routes and sheets follow locale without translating filenames',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScannerApp(preferences: preferences, home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => preferences.update(language: 'fr'));
    await tester.pumpAndSettle();
    expect(find.text('Fichiers récents'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget); // User filename, not the Share action.
    await tester.tap(find.text('Share'));
    await waitFor(tester, find.text('Ouvrir les outils du document'));
    expect(find.text('Share.txt'), findsOneWidget);
    await tester.runAsync(() => preferences.update(language: 'ar'));
    await tester.pumpAndSettle();
    expect(find.text('فتح أدوات المستند'), findsOneWidget);
    expect(find.text('طباعة'), findsOneWidget);
    expect(find.text('Share.txt'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(BottomSheet))), TextDirection.rtl);
    await tester.runAsync(() async {
      expect(await store.fileFor(store.files.single).readAsString(),
          'Original scan: Save Share {count}');
      final restored = AppPreferences(file: preferences.file);
      await restored.load();
      expect(restored.language, 'ar');
      restored.dispose();
    });
    await tester.tap(find.byTooltip('إغلاق خيارات الملف'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('selecting Bengali in Settings also updates Home', (tester) async {
    final singleton = AppPreferences.instance;
    final previousFile = singleton.file;
    final previousLanguage = singleton.language;
    singleton.file = File('${directory.path}/settings.json');
    singleton.language = 'en';
    addTearDown(() {
      singleton.file = previousFile;
      singleton.language = previousLanguage;
      singleton.notifyListeners();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScannerApp(home: HomeScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-bn')));
    await waitFor(tester, find.text(AppStrings.translate('Choose App Language', 'bn')));
    final backLabel = MaterialLocalizations.of(tester.element(
        find.byKey(const ValueKey('language-bn')))).backButtonTooltip;
    await tester.tap(find.byTooltip(backLabel));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('স্ক্যানের বিকল্প'), findsOneWidget);
    expect(find.text('সাম্প্রতিক ফাইল'), findsOneWidget);
    expect(find.text('Share.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in AppStrings.languages) {
    testWidgets('$language translates code result actions and retains scan contents',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);
      preferences.language = language;
      var copied = false;
      const value = 'Save {count} https://example.com/العربية';
      await tester.pumpWidget(ScannerApp(preferences: preferences,
        home: CodeResultScreen(qrOnly: true, value: value,
          onClose: () {}, onOpen: () {}, onSave: () {},
          onCopy: () => copied = true, onPromotion: () {})));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.translate('QR Code Detected', language)), findsOneWidget);
      expect(find.text(value), findsOneWidget);
      await tester.tap(find.text(AppStrings.translate('Copy', language)));
      expect(copied, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
