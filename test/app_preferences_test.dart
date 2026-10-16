import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/data/app_preferences.dart';
import 'package:pdf_scanner/services/scan_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('first-language completion persists only with a successful commit', () async {
    final dir = await Directory.systemTemp.createTemp('language_setup_');
    final prefs = AppPreferences(file: File('${dir.path}/settings.json'));
    try {
      await prefs.load();
      expect(prefs.languageSetupComplete, isFalse);
      await prefs.update(vibration: false);
      final pending = AppPreferences(file: prefs.file);
      await pending.load();
      expect(pending.languageSetupComplete, isFalse);
      pending.dispose();
      await Future.wait([
        prefs.completeLanguageSetup('bn'),
        prefs.update(beep: false),
      ]);
      final restored = AppPreferences(file: prefs.file);
      await restored.load();
      expect(restored.language, 'bn');
      expect(restored.languageSetupComplete, isTrue);
      expect(restored.vibration, isFalse);
      expect(restored.beep, isFalse);
      restored.dispose();
    } finally {
      prefs.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('old saved languages migrate; unfinished and invalid choices do not', () async {
    final dir = await Directory.systemTemp.createTemp('language_migration_');
    try {
      final file = File('${dir.path}/settings.json');
      for (final record in [
        ('{"language":"fr"}', true),
        ('{"language":"en","languageSetupComplete":false}', false),
        ('{"language":"unknown","languageSetupComplete":true}', false),
        ('{"beep":false}', false),
      ]) {
        await file.writeAsString(record.$1);
        final prefs = AppPreferences(file: file);
        await prefs.load();
        expect(prefs.languageSetupComplete, record.$2);
        prefs.dispose();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('failed first-language save cannot mark setup complete', () async {
    final dir = await Directory.systemTemp.createTemp('language_failed_save_');
    try {
      final blocker = await File('${dir.path}/blocked').writeAsString('file');
      final prefs = AppPreferences(file: File('${blocker.path}/settings.json'));
      await expectLater(prefs.completeLanguageSetup('ar'),
          throwsA(isA<FileSystemException>()));
      expect(prefs.languageSetupComplete, isFalse);
      expect(prefs.language, 'en');
      prefs.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });

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

  test('saved feedback switches control the feedback service', () async {
    final output = _PreferencesFeedbackOutput();
    final prefs = AppPreferences(feedback: ScanFeedback(output: output))
      ..vibration = false
      ..beep = false;

    await prefs.scanFeedback();
    await prefs.prepareScanFeedback();
    expect(output.calls, isEmpty);

    prefs.beep = true;
    await prefs.prepareScanFeedback();
    expect(output.calls, ['prepare']);
    output.calls.clear();
    await prefs.scanFeedback();
    expect(output.calls, ['beep']);

    output.calls.clear();
    prefs.beep = false;
    prefs.vibration = true;
    await prefs.scanFeedback();
    expect(output.calls, ['vibrate']);

    output.calls.clear();
    prefs.beep = true;
    await prefs.scanFeedback();
    expect(output.calls, ['beep', 'vibrate']);
    prefs.dispose();
  });
}

class _PreferencesFeedbackOutput implements ScanFeedbackOutput {
  final calls = <String>[];
  @override
  Future<void> prepareBeep() async => calls.add('prepare');
  @override
  Future<void> playBeep() async => calls.add('beep');
  @override
  Future<void> vibrate() async => calls.add('vibrate');
}
