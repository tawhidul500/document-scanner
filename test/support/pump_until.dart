import 'package:flutter_test/flutter_test.dart';

/// Advances Flutter frames and lets real filesystem work finish between them.
/// Waiting for an observable result avoids fixed sleeps and indeterminate
/// progress indicators that can never satisfy pumpAndSettle while I/O is pending.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final elapsed = Stopwatch()..start();
  while (true) {
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
    if (elapsed.elapsed >= timeout) fail('Timed out waiting for $reason');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}
