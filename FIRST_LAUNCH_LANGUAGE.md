# First-launch language selection

Startup now follows this sequence:

1. Show the supplied opening animation while preferences and saved files load.
2. On a new installation, show Choose App Language with all nine languages.
3. Selecting a language previews the screen in that language, including Arabic
   reading direction. It does not navigate or save yet.
4. Next becomes enabled after selection. It saves the language and the
   `languageSetupComplete` flag together through the existing serialized,
   atomic preferences write. Only a successful save allows Home to appear.
5. Subsequent launches use the saved language and open Home after loading.

The language list uses the same choices and supplied icon as Settings. The
screen supports light/dark/system appearance, scrolling, larger text, and a
Next button that remains below the scrolling list. Language can still be
changed later through Settings.

Leaving before Next keeps setup pending. Save failure displays a translated
error and allows retry; it cannot mark setup complete. Repeated Next taps are
guarded while saving. Existing installations with a valid saved language and
no completion flag keep their choice and skip the new first-launch screen.
An explicit false flag or invalid saved language still requires setup.

## Verification

- Parsed all 78 Dart source/test files without syntax errors and checked local imports.
- Translation coverage: all three checks passed, including the three new
  onboarding messages in all eight non-English languages.
- Existing palette and QR/barcode contrast checks passed.
- Preserved the uploaded opening-animation JSON unchanged.
- Verified archive integrity and preservation of the previous source files.

Added preference and widget regression coverage for first launch, explicit
selection, Next, save failure/retry, interrupted setup, later launches, legacy
preferences, concurrent writes, Arabic, enlarged text, and both appearances.
Updated the existing startup tests for preference loading and returning users.

The Flutter/Dart SDK is unavailable here. Flutter analysis, widget test execution,
native builds, and device verification have not been performed. Run:

```sh
flutter pub get
flutter analyze
flutter test test/app_preferences_test.dart test/language_setup_test.dart test/splash_screen_test.dart
flutter test
```

This is the cumulative updated source package, including all previous fixes.
