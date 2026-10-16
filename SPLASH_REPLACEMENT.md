# Opening animation replacement

The supplied `f3b85134-6e59-4c33-81d7-654c3e88fbd8.json` is now the runtime
`assets/splash/opening_animation.json`, copied byte-for-byte with all 14 layers,
including its Loader. It is 375 × 812 at 30 fps, with a six-second animation loop.

SHA-256: `3c52889acacfd42dcc042ea1b79066c9e5807aa4e748a17e2321213114c4e2dc`

The old modified runtime JSON, static splash images, and separate Flutter
progress bar have been removed. The new animation runs in every language and
appearance mode. For non-English locales, three English vector-text layers
are hidden through Lottie opacity delegates and translated labels are drawn
at their corresponding positions. Animation artwork and the built-in loader
remain present. Reduced-motion settings pause the animation.

The supplied blue gradient is preserved in both appearance modes, including
the surrounding space on different screen ratios. Artwork scales uniformly;
it is not stretched or cropped. Startup progress is still exposed to screen
readers. Preferences now load after Flutter starts, so the animation can show
while preferences and saved files initialize. Returning users open Home when
loading succeeds; new users first select a language and tap Next, as described
in `FIRST_LAUNCH_LANGUAGE.md`. The six-second loop does not introduce an
artificial delay. Retry behavior is unchanged.

The native OS launch screen is static: its configuration now uses a plain
matching blue background and a transparent Android 12 launch image, removing
the previous logo before Flutter starts. Existing native runners must regenerate
their splash resources. The provided setup/build commands already do this:

```sh
python3 tool/setup.py
# Or, if native runners already exist:
flutter pub get
dart run flutter_native_splash:create
flutter test test/splash_screen_test.dart
```

Validation: uploaded/runtime JSON byte equality, local imports and asset paths,
Dart syntax parsing, localization coverage, contrast checks, and archive
integrity were checked. The startup widget tests were updated for the new
animation, translated captions, actual progress semantics, small screens,
reduced motion, retry, and immediate completion.

Flutter/Dart are unavailable in this environment, so widget tests, device
playback, native splash generation, and app builds have not been executed here.
This package is updated app source, not a compiled APK.

Lottie integration follows the package's [documented runtime delegates](https://github.com/xvrh/lottie-flutter#modify-properties-at-runtime).
