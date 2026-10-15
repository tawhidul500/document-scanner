import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.runAsync(store.load);
    final completion = Completer<DocumentStore>();
    late ValueChanged<double> report;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
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
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('startup-progress')),
          )
          .value,
      isNull,
    );
    report(0.4);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('startup-progress')),
          )
          .value,
      0.4,
    );
    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(HomeScreen), findsNothing);
    completion.complete(store);
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    dir.deleteSync(recursive: true);
  });

  testWidgets('failed startup offers retry and fast success opens Home', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('startup_retry_');
    final store = DocumentStore(dir);
    await tester.runAsync(store.load);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          loader: (_) async {
            if (attempts++ == 0) throw const FileSystemException('Unavailable');
            return store;
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dir.deleteSync(recursive: true);
  });

  testWidgets('splash progress fits a small phone with safe insets', (
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
    final rect = tester.getRect(find.byKey(const ValueKey('startup-progress')));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(534));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
