# App-wide language update

The saved language now controls `MaterialApp.locale`. Flutter's Material,
Cupertino, and widget localization delegates handle built-in controls and Arabic
text direction. The app's shared `AppText` widget and `context.tr()` observe the
locale, so already-open routes and sheets rebuild without resetting navigation,
scanner sessions, or documents.

Supported languages: English, Bengali, Hindi, Arabic, Spanish, French, Russian,
Indonesian, and Portuguese. The shared catalog includes 343 messages, with 2,744
non-English translations and named placeholders for filenames and counts.

Coverage includes Home, Recent and all folder screens, search and selection,
file menus, scanner prompts, QR/barcode results, document review and editing,
signature tools, OCR, PDF import, export/share feedback, dialogs, validation,
Settings, About, and startup. Labels embedded in the original Home/navigation
artwork are replaced with translated text in other languages. The English
reference artwork remains in use for English. Translated result screens use
the adaptive layout; category filters scroll when their labels need more space.

User filenames, folder names, PDF contents, recognized text, and QR/barcode
payloads are never translated. Format identifiers (PDF, CODE 128, Wi-Fi/vCard),
filter preset names Aden/Amaro, and the Google Play brand retain their names.
System-owned camera permissions, native print/share/export dialogs, and other
apps follow their own or the device's language settings. UI language selection
does not change the existing Latin-script OCR recognizer.

## Verification

Passed locally:

- Dart syntax parsing across all 71 application and test files.
- Three localization checks: all eight translations for every message,
  matching placeholders, and coverage of literal UI text.
- Three existing light/dark and scan-result contrast checks.
- ZIP integrity and comparison against the previous cumulative package.

Added Flutter regression tests for the actual Settings language selector,
locale changes on existing routes and open sheets, Arabic directionality,
saved language restoration, unchanged filenames and scan contents, and the
QR result screen in all nine languages.

Flutter/Dart SDK and native runners are unavailable here. Flutter analysis,
widget tests, compilation, and device rendering have not been run. After
dependency resolution, run `flutter analyze`, `flutter test`, and verify the
screens on Android/iOS with Bengali, Arabic, and a longer-label language such
as French or Russian. Source package only; no APK/IPA was built.

Flutter localization reference: https://docs.flutter.dev/ui/internationalization
