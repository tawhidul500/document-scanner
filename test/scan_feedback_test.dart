import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_scanner/services/scan_feedback.dart';

class FakeFeedbackOutput implements ScanFeedbackOutput {
  final calls = <String>[];
  bool failBeep = false;
  bool failVibration = false;
  Completer<void>? vibrationWait;

  @override
  Future<void> prepareBeep() async => calls.add('prepare');

  @override
  Future<void> playBeep() async {
    calls.add('beep');
    if (failBeep) throw StateError('Audio device unavailable');
  }

  @override
  Future<void> vibrate() async {
    calls.add('vibrate');
    if (failVibration) throw StateError('Vibrator unavailable');
    await vibrationWait?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final flags in [(false, false), (true, false), (false, true), (true, true)]) {
    test('feedback honors beep=${flags.$1}, vibration=${flags.$2}', () async {
      final output = FakeFeedbackOutput();
      final feedback = ScanFeedback(output: output);
      await feedback.play(beep: flags.$1, vibration: flags.$2);
      expect(output.calls, [
        if (flags.$1) 'beep',
        if (flags.$2) 'vibrate',
      ]);
    });
  }

  test('preloading a scanner does not beep or vibrate', () async {
    final output = FakeFeedbackOutput();
    await ScanFeedback(output: output).prepare();
    expect(output.calls, ['prepare']);
  });

  test('audio failure leaves vibration working and scan completion safe', () async {
    final output = FakeFeedbackOutput()..failBeep = true;
    await ScanFeedback(output: output).play(beep: true, vibration: true);
    expect(output.calls, ['beep', 'vibrate']);
  });

  test('vibration failure leaves the beep working', () async {
    final output = FakeFeedbackOutput()..failVibration = true;
    await ScanFeedback(output: output).play(beep: true, vibration: true);
    expect(output.calls, ['beep', 'vibrate']);
  });

  test('slow vibration never delays starting the beep', () async {
    final output = FakeFeedbackOutput()..vibrationWait = Completer<void>();
    final done = ScanFeedback(output: output).play(beep: true, vibration: true);
    expect(output.calls, ['beep', 'vibrate']);
    output.vibrationWait!.complete();
    await done;
  });

  test('bundled beep is registered and contains PCM audio', () async {
    final data = await rootBundle.load('assets/sounds/scan_success.wav');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
    expect(bytes.length, greaterThan(44));
  });
}
