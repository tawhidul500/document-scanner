# Document and ID card menu fixes

This cumulative source update includes all previous scanner, file-action,
download, appearance, and nine-language changes.

## Close-button bug

Document and ID card options used a Stack whose width was determined by the
title. Positioning the cross within that Stack placed it over the title.
All six bottom-sheet entry points now use AppActionSheet, with a full-width
header, an independent 48 × 48 close target, and equal space on the opposite
side so the title stays centered. The cross uses the supplied SVG path inside
its 24-pixel circular background. Titles wrap independently of the button,
and Arabic layouts put the button on the trailing edge. The header stays in
place while action rows scroll. Sheets respect safe areas and cap tablet width.

Affected menus: document review, ID card preview, files opened from Recent or
folders, folder options, and both Move Files sheets.

## Visual consistency

- Shared menu rows now have consistent spacing, dividers, type, and icon color.
- Ten action icons are extracted from the original SVG references. Common
  menu and toolbar actions use the same artwork and tint it for the active
  appearance, selection, and disabled state.
- Document, editor, signature, folder, and Recent toolbars share icon sizing,
  captions, spacing, and disabled colors. The five document actions have equal
  widths and labels can wrap without pushing another action out of its row.
- Light backgrounds match the supplied F6F9FE reference. Close controls have
  explicit light and dark surfaces, and app bars no longer acquire a different
  elevation tint when content scrolls underneath them.
- Done/Option controls and the signature confirmation button now show their
  disabled state. Signature placement controls use the active theme palette.
- The language screen uses the same supplied language icon as Settings.
  Settings switches follow the reading direction in Arabic.
- Original camera/result artwork, document pixels, and signature ink colors
  are retained. Print, Share, Export, and document-action callbacks are retained.

## Validation

Completed in the available environment:

- Parsed all 75 Dart source and test files with tree-sitter: no syntax errors.
- Translation coverage and placeholders: 3 Python checks passed.
- Semantic palette contrast, including the close button: 2 Python checks passed.
- QR/barcode result contrast: 1 Python check passed.
- Inspected extracted action artwork in both light and dark colors.
- Checked bundled asset paths, local Dart imports, and cumulative archive
  completeness against the previous delivered source.

The Flutter/Dart SDK is unavailable here. Flutter analysis, widget tests,
Android/iOS builds, and live-device pixel comparisons have NOT been run.
This source update does not claim full-app pixel-perfect device verification.

Added test/action_sheet_layout_test.dart covers both reported titles at 320,
375, 430, and 800 pixels, light/dark themes, English/Arabic, and 1×/2× text.
It checks title/button separation, centering, the 48-pixel target, dismissal,
sticky headers during scrolling, and selected/disabled toolbar colors.

Run on a Flutter 3.44+ development machine:

```sh
flutter pub get
flutter analyze
flutter test test/action_sheet_layout_test.dart test/file_actions_sheet_test.dart test/app_localization_test.dart test/appearance_test.dart
flutter test
```

Rebuild the action artwork if needed with:
`python3 tool/action_artwork/build_assets.py` (requires Inkscape and Pillow).
