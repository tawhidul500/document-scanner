# QR and barcode scan feedback fix

The old implementation requested a system touch-click and a medium haptic effect.
The updated implementation plays a bundled PCM beep with audioplayers 6.8.1 and
requests a 180 ms vibration using vibration 3.2.1.

- Both effects follow the existing Settings switches.
- Audio is preloaded when the QR/barcode scanner opens, without playing a sound.
- Automatic camera scans, manual capture, and imported code images retain the
  same feedback calls. Manual capture now uses the same guarded result handler.
- Audio and vibration start independently; device failures do not discard scans.
- The previous navigation corner fix is included.
- No microphone or extra storage permission is required. Android's VIBRATE
  permission is already added by tool/setup.py.
- Android playback uses media volume. iOS playback respects Silent Mode.
  System volume, device vibration availability and OS restrictions still apply.

## Rebuild required

Stop the running app completely: hot reload cannot register the new plugins.

From the project root, with Flutter on PATH:

```sh
python3 tool/setup.py --skip-checks
flutter pub get
flutter analyze
flutter test
flutter run
```

For an Android APK, the existing build workflow also configures permissions:

```sh
python3 tool/build.py apk
```

Test on a physical device with both switches enabled and media volume audible.
Scan a QR code, rescan, scan a barcode, and try manual capture and image import.
Then test each switch separately and both switched off. Each accepted code
should trigger each enabled effect once.

## Validation

The setup regression check, WAV integrity checks and ZIP checks were run during
this update. Flutter/Dart are unavailable in the editing environment; Flutter
analysis, the added regression tests, native builds and hardware feedback remain
to be verified with the commands above.

API references:
- https://pub.dev/packages/audioplayers/versions/6.8.1
- https://pub.dev/packages/vibration/versions/3.2.1
