import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// The device operations are separate so settings and failure handling can be
/// verified without requiring a speaker, a vibrator, or a running camera.
abstract interface class ScanFeedbackOutput {
  Future<void> prepareBeep();
  Future<void> playBeep();
  Future<void> vibrate();
}

class ScanFeedback {
  ScanFeedback({ScanFeedbackOutput? output})
      : _output = output ?? DeviceScanFeedbackOutput();

  static final instance = ScanFeedback();
  final ScanFeedbackOutput _output;

  Future<void> prepare() => _attempt('beep preparation', _output.prepareBeep);

  Future<void> play({required bool beep, required bool vibration}) async {
    // Start both independently. A missing audio device/plugin must not suppress
    // vibration, and a slow vibration call must not delay the beep.
    await Future.wait<void>([
      if (beep) _attempt('beep', _output.playBeep),
      if (vibration) _attempt('vibration', _output.vibrate),
    ]);
  }

  Future<void> _attempt(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      // Feedback failure must never discard a successfully decoded scan.
      // No scanned contents are logged.
      debugPrint('Scan feedback ($name) unavailable: $error');
    }
  }
}

class DeviceScanFeedbackOutput implements ScanFeedbackOutput {
  AudioPlayer? _player;
  Future<void>? _preparation;

  @override
  Future<void> prepareBeep() async {
    final preparation = _preparation ??= _configurePlayer();
    try {
      await preparation;
    } catch (_) {
      // A later scan can retry if loading the sound temporarily failed.
      if (identical(_preparation, preparation)) _preparation = null;
      rethrow;
    }
  }

  Future<void> _configurePlayer() async {
    final player = _player ??= AudioPlayer();
    await player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        // Use media playback rather than Android's optional touch-click sounds.
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ));
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0.85);
    await player.setSource(AssetSource('sounds/scan_success.wav'));
  }

  @override
  Future<void> playBeep() async {
    await prepareBeep();
    final player = _player!;
    await player.seek(Duration.zero);
    await player.resume();
  }

  @override
  Future<void> vibrate() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 180);
    }
  }
}
