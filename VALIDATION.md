# Version 0.4.0 validation

- Both supplied SVGs were rendered and visually inspected; originals included under design/.
- All Dart sources/tests parsed using tree-sitter Dart; no syntax errors.
- YAML, declared assets, setup Python syntax and ZIP integrity checked locally.
- Added tests for contour detection, blank scenes, stable capture timing, motion reset, duplicate prevention, image rotation, PDF generation and persistent PDF replacement.
- Standalone Dart 3.13.5 analyzer passed for edge_detector.dart and page_processing.dart with image/pdf dependencies resolved. The executable checks in tool/check_document_processing.dart passed for synthetic contour detection, blank scenes, stability timing, duplicate prevention/rearm, image rotation/crop/signature and PDF generation. These are synthetic checks, not camera-device tests.
- Flutter widget/store tests are supplied but not run with Flutter. Flutter analyzer, dependency resolution, rendered Flutter layout, Android/iOS build and physical-device acceptance remain unverified.
- The camera page uses a custom heuristic detector. Poor lighting, shadows, complex backgrounds and strongly tilted pages can require manual capture/crop. Verify actual accuracy on target hardware before release.

## Previous validation

# Version 0.3.1 validation

Checked JSON decoding, original asset preservation, removal of only the timed Loader layer, pubspec asset references, Python setup syntax and ZIP integrity locally.
Flutter/Dart are not installed in the editing environment. No analyzer, Flutter tests, rendering, dependency resolution, or device build was run for this update.
New/replaced tests cover pending startup beyond six seconds, work progress, fast completion, retry, small-screen bounds, corrupt records and an empty store. Run these tests with Flutter before release.
The previous static-splash geometry tests were replaced because the design changed.

## Previous version validation record

# Validation — version 0.3.0

Completed:
- Parsed and rendered all three supplied SVGs; visually inspected the home/camera-menu references and extracted icons.
- Extracted individual scan/folder/logo artwork at 1x and 4x; verified asset files and font license are packaged.
- Parsed all Dart sources with the tree-sitter Dart grammar: no syntax errors.
- Ran the downloaded standalone Dart formatter on all application files and initial tests successfully. This checks Dart parsing, not Flutter types.
- Python setup script compiled successfully; native configuration edits are provided for local execution.
- Parsed YAML and checked asset references and ZIP integrity.

Not completed:
- Flutter package resolution, analyzer, widget tests, visual rendering and Android/iOS builds.
- Actual device camera, permission, cropping, scanning, sharing and system export tests.
- Pixel-level comparison of a rendered Flutter frame against the Figma reference.

The Flutter SDK download succeeded, but automatic approval review blocked the Flutter bootstrap/verification command because it attempted to contact a link-local cloud metadata endpoint. That attempt was stopped. No successful Flutter analyzer/test result is claimed.

The ZIP contains source, assets, setup scripts, and tests. Native Android/iOS runner folders must be generated with tool/setup.py on a local Flutter installation. No APK/IPA is included.

Tests supplied:
- Reference-size splash placement and small-screen layout.
- Local-file persistence, Unicode code content, rename/delete, corrupt-record isolation, unsafe-name rejection.
- Home counts, case-insensitive search and small-screen empty state.
- Optional actual Flutter Home PNG capture: `flutter test test/visual_preview_test.dart --dart-define=CAPTURE_PREVIEW=true`.

A font named Inter is bundled as a visual approximation for dynamic text; SVG outlines alone do not confirm the original typeface. Header artwork is preserved exactly.

Version 0.3 checks: all 11 Dart sources/tests parse without errors; YAML and declared assets validated. New widget tests cover exact menu reference geometry, action selection, X/outside/Back dismissal. New store tests cover PDF-header rejection and durable import without modifying the original. These Flutter tests are supplied but unrun. No retry of the blocked Flutter bootstrap was made.
