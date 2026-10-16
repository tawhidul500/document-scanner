# Repository preparation — 2026-10-16

The cumulative source update is version 0.5.0+6, based on repository main
`50d1d21bfbba110b6d987fe1493b4c1049a46aa3`. The existing build fixes are retained.
The manual workflow defaults to Android and retains optional iOS builds. It adds
localization/contrast checks and includes an APK SHA-256 checksum in the artifact.
See `GITHUB_UPDATE.md` for push and build instructions.

Flutter is not installed in this session. No Flutter analysis, widget tests, native
build, APK, or device verification has been completed here. The workflow retains
analysis and the complete Flutter test suite as mandatory build gates.

Local preparation checks passed: 79 Dart files parsed, local imports and declared
assets resolved, seven Python checks passed (localization, contrast, native setup),
and workflow/Python syntax checks passed. These are source checks, not a Flutter build.

The earlier report below describes the original build preparation; later feature
notes and the current README supersede older feature descriptions.

---

# Build and optimization report — 2026-10-15

## Result

**No APK, IPA, or compiled iOS app was produced. This is a source delivery, not a
verified successful build.** The environment is Linux, without Android SDK or
Xcode initially. Flutter 3.47.7 was downloaded from the official stable repository,
including its Dart 3.13.5 engine SDK. The Dart runtime aborts before running Flutter
commands with `Failed to retrieve stack bounds`; even native `dart format` fails.
This workspace does not expose `/proc/self`. The runtime failure prevents pub get,
Flutter analysis, tests and Android compilation. No claim of successful native
compilation or runtime validation is made.

The iOS command stops with a macOS/Xcode prerequisite error. An installable IPA
also requires Apple signing/provisioning. An unsigned .app ZIP is not an IPA and
cannot be installed directly on an iPhone.

## Fixed and optimized

- Corrected pubspec minimum SDK to Dart 3.12 / Flutter 3.44. Official pub.dev metadata
  confirms camera 0.12.1 and flutter_file_dialog 3.3.3 require this baseline; PDF
  and printing also require Dart 3.12. Previous 3.10/3.38 documentation was wrong.
- Lazy folder lists avoid eagerly building every file row. Folder counts and valid
  selected IDs now use one pass instead of repeated scans per folder/selection.
- Camera lifecycle start/stop/disposal operations are serialized to prevent races
  when resuming, detecting, closing a result or leaving the scanner.
- Preference writes are queued, preventing overlapping updates to the temporary
  JSON file and preserving the latest state.
- Updated the Home search regression expectation for extension-free QR names in
  Recent Files.
- Formatted and syntax-parsed all 41 Dart files with the WebAssembly dart_style
  port. This is **syntax validation only**, not type checking or Flutter analysis.
- Native setup now creates runners in an isolated temporary scaffold, preserving
  authored source, tests, dependencies, README and existing runners.
- Setup is idempotent; includes Android vibration permission and app display name,
  iOS usage descriptions, CocoaPods fallback, iOS 15.5 framework metadata, and
  Android minimum SDK/toolchain prerequisites.
- Added a fail-fast build entry point and a manual Android/macOS CI workflow.
  Build artifacts are copied only after verification and native build succeed.

## Checks actually completed

- All 11 exact pinned dependency versions queried successfully from official pub.dev.
- MobileScanner analyzeImage/errorBuilder/controller and PDF Document APIs checked
  against downloaded package source.
- 41 Dart files accepted by the WebAssembly formatter/parser; no syntax errors.
- Python build/setup scripts compiled successfully.
- `python3 tool/test_setup.py` passed: native fixture configuration, minimum versions,
  permissions, app metadata, authored-file preservation and repeated-run idempotence.
- ZIP integrity checked before delivery.

## Checks still required

- Successful flutter pub get and retained pubspec.lock.
- flutter analyze, flutter test, native Android/iOS compilation.
- Physical device camera/QR/gallery, lifecycle, storage, share/export and layout tests.
- Store identity/signing, real support URLs and final language scope review.

## Build on a supported machine

Install Flutter 3.47.7, JDK 17 and Android SDK. Accept Android SDK licenses using
`flutter doctor --android-licenses`, then run `python3 tool/build.py apk` from this
folder. Output on success: `dist/document-scanner-android-test.apk`. It is a
release-mode build using Flutter's generated development signing unless you
configure your own production signing.

On a Mac with Xcode and CocoaPods, run `python3 tool/build.py ios` to verify an
unsigned device app. For an installable IPA, first generate runners with
`python3 tool/setup.py --skip-checks --org your.reverse.domain`, configure Runner's
bundle identifier and signing team in Xcode, then run `python3 tool/build.py ipa`.
The signed export is under `build/ios/ipa/`. Apple distribution mode/profiles must
match your intended installation method.

The supplied `.github/workflows/build.yml` can run these builds on GitHub Actions
when you add the source to your repository and manually start the workflow. It has
not been executed here and makes no deployment or store submission.

Existing product limitations remain: Settings/Language-only translations, unconfigured
publisher links, Latin OCR, rasterized PDF merging and no image-document storage.
