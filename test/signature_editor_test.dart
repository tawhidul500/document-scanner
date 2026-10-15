import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/features/document/signature_editor.dart';

void main() {
  test('signature bounds include every stroke and brush padding', () {
    const ink = SignatureInk(
      [
        [Offset(10, 20), Offset(50, 60)],
        [Offset(30, 15), Offset(70, 40)],
      ],
      Colors.blue,
      30,
    );
    final bounds = ink.bounds(30);
    expect(bounds.left, lessThan(10));
    expect(bounds.top, lessThan(15));
    expect(bounds.right, greaterThan(70));
    expect(bounds.bottom, greaterThan(60));
    expect(ink.bounds(60).width, greaterThan(bounds.width));
  });

  testWidgets('draw, undo and redo control whether a signature can be used', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignatureDrawScreen()));
    expect(find.text('Sign here'), findsOneWidget);
    IconButton useButton() =>
        tester.widget<IconButton>(find.byTooltip('Use signature'));
    expect(useButton().onPressed, isNull);
    final canvas = find.byKey(const ValueKey('signature-canvas'));
    await tester.dragFrom(
      tester.getTopLeft(canvas) + const Offset(50, 100),
      const Offset(100, 40),
    );
    await tester.pump();
    expect(useButton().onPressed, isNotNull);
    expect(find.text('Sign here'), findsNothing);
    await tester.tap(find.byTooltip('Undo stroke'));
    await tester.pump();
    expect(useButton().onPressed, isNull);
    await tester.tap(find.byTooltip('Redo stroke'));
    await tester.pump();
    expect(useButton().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new stroke after undo clears redo history', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignatureDrawScreen()));
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('signature-canvas')),
    );
    await tester.dragFrom(origin + const Offset(40, 80), const Offset(70, 30));
    await tester.pump();
    await tester.tap(find.byTooltip('Undo stroke'));
    await tester.pump();
    await tester.dragFrom(origin + const Offset(80, 150), const Offset(40, 20));
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byTooltip('Redo stroke')).onPressed,
      isNull,
    );
  });

  testWidgets('confirmation returns drawn strokes to the placement screen', (
    tester,
  ) async {
    SignatureInk? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<SignatureInk>(
                  MaterialPageRoute(
                    builder: (_) => const SignatureDrawScreen(),
                  ),
                );
              },
              child: const Text('Draw'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('signature-canvas')),
    );
    await tester.dragFrom(
      origin + const Offset(50, 100),
      const Offset(120, 20),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Use signature'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.strokes.single.length, greaterThan(1));
    expect(find.text('Draw'), findsOneWidget);
  });
}
