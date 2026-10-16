import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/widgets/reference_navigation.dart';
import 'package:pdf_scanner/widgets/scan_empty_state.dart';

void main() {
  testWidgets('shared navigation retains all three interactive targets', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 813);
    addTearDown(tester.view.reset);
    var home = 0, scan = 0, settings = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      bottomNavigationBar: ReferenceHomeNavigation(
        settingsSelected: true, homeSelected: false,
        onHome: () => home++, onScan: () => scan++,
        onSettings: () => settings++,
      ),
      body: const Center(child: ScanEmptyState()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('No files here yet'), findsOneWidget);
    for (final label in ['Home', 'Scan', 'Settings']) {
      await tester.tap(find.byTooltip(label));
    }
    expect([home, scan, settings], [1, 1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search empty state gives search-specific guidance', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: ScanEmptyState(search: true)),
    )));
    expect(find.text('No matching files'), findsOneWidget);
    expect(find.text('Try another file name.'), findsOneWidget);
    expect(find.textContaining('camera button'), findsNothing);
  });

  testWidgets('open camera menu removes camera artwork but retains side tabs',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final width in [320.0, 375.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(
        bottomNavigationBar: ReferenceHomeNavigation(cameraVisible: false),
      )));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Scan'), findsNothing);
      expect(find.byTooltip('Home'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsNothing);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
