import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('language and feedback settings survive reload', () async {
    final dir = await Directory.systemTemp.createTemp('preferences_');
    try {
      final file = File('${dir.path}/settings.json');
      final prefs = AppPreferences(file: file);
      await prefs.load();
      expect(prefs.language, 'en');
      await prefs.update(language: 'bn', vibration: false, beep: false);
      final reloaded = AppPreferences(file: file);
      await reloaded.load();
      expect(reloaded.language, 'bn');
      expect(reloaded.vibration, isFalse);
      expect(reloaded.beep, isFalse);
      await expectLater(
        reloaded.update(language: 'unknown'),
        throwsArgumentError,
      );
      expect(reloaded.language, 'bn');
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('overlapping preference updates preserve each field', () async {
    final dir = await Directory.systemTemp.createTemp('preferences_queue_');
    try {
      final prefs = AppPreferences(file: File('${dir.path}/settings.json'));
      await Future.wait([
        prefs.update(language: 'fr'),
        prefs.update(vibration: false),
        prefs.update(beep: false),
      ]);
      final reloaded = AppPreferences(file: prefs.file);
      await reloaded.load();
      expect(reloaded.language, 'fr');
      expect(reloaded.vibration, isFalse);
      expect(reloaded.beep, isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test(
    'disabled feedback is silent and enabled feedback reaches platform',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call.method);
            return null;
          });
      try {
        final prefs = AppPreferences()
          ..vibration = false
          ..beep = false;
        await prefs.scanFeedback();
        expect(calls, isEmpty);
        prefs.vibration = true;
        await prefs.scanFeedback();
        expect(calls, ['HapticFeedback.vibrate']);
        calls.clear();
        prefs.vibration = false;
        prefs.beep = true;
        await prefs.scanFeedback();
        expect(calls, ['SystemSound.play']);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      }
    },
  );
}
