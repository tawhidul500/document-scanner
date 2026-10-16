# QR and barcode scan result redesign

The result pages now use the supplied `QR-Code_page_redesign.svg` and
`Barcode_page_redesign.svg`. Both source SVGs are retained in
`design/scan_results/`. Previous app fixes and appearance settings are included.

The latest precision pass replaces the default flexible layout with an explicit
375 × 812 reference canvas. Card and button bounds, text baselines, icon bounds,
gradient stops, shine, rings, corner radii, shadow offsets/blur, and the promo
group’s 22px translation now follow the SVG coordinates. Standard light mode
uses the original SVG colors, without the earlier darkening.

## Interface

- Blue/purple background, concentric rings, rounded translucent result card,
  matching Open/Search, Copy and Save icons, close/back controls, barcode format
  chip, promotional illustration, feature chips and Google Play button.
- Icons and illustration are extracted from the supplied vector paths at 4x.
  UI text and scanned values are native widgets, never baked into screenshots.
- Barcode format comes from the actual decoder, including manual capture and
  image import. The reference's sample EAN-13 value is not used as app data.
- Standard light mode preserves the supplied light palette exactly. Dark mode
  uses navy/purple backgrounds, darker cards/buttons and pale action icons. Both
  follow the existing Light/Dark/System preference immediately. The reference
  light palette does not achieve 4.5:1 for every small white label; high-contrast
  mode uses the deeper accessible palette instead.
- The default canvas scales uniformly with width. Extra notch space is added
  only beyond the 24px already reserved in the design; the actual system home
  indicator is used. Long values scroll inside the preview and the page scrolls.
  Widths below 350px, adjusted text scaling and high-contrast mode use the
  adaptive native layout with accessible colors and stacked actions as needed.

## Actions

- QR Open launches only HTTP/HTTPS links; other payloads remain selectable,
  copyable and saveable.
- Barcode Search opens a Google search for the scanned value. Query parameters
  are encoded, including punctuation and Unicode.
- Copy preserves the complete value. Save returns the same value to the
  existing local TXT saving flow without briefly restarting the camera.
- Back, system Back and the close icon return to scanning. Scan feedback
  and duplicate-result protection are preserved.

## Google Play destination

Set `QR_GENERATOR_APP_URL` to the promoted app's actual HTTPS store URL using
`--dart-define` or the existing `tool/build.py --defines` JSON option. If absent,
the existing `MORE_APPS_URL` value is used. No destination was supplied with
the design, so no app package ID or listing has been guessed. Without a valid
URL, tapping the promotion shows the existing-style unavailable-link message.

## Validation

Completed in this environment:

- Parsed all 66 Dart application/test files with tree-sitter, without syntax
  errors. This is not Dart static analysis.
- Passed `python3 tool/test_theme_contrast.py` and
  `python3 tool/test_code_result_contrast.py`. The latter checks the accessible
  adaptive palette and shared dark palette, including translucent layers. It
  does not claim the original standard-light SVG palette passes 4.5:1.
- Compared reference card/preview/CTA bounds, text baselines, gradient colors,
  opacity and ring coordinates in the source against the supplied SVGs.
- Rendered/inspected the extracted artwork; checked PNG decoding and ZIP
  integrity; verified earlier files remain unchanged outside this update.

Added Flutter regression coverage for actions, payload URL handling, detected
format labels, both themes, long data and large text on narrow screens.
`test/code_result_reference_geometry_test.dart` additionally reads expected
rectangles and baselines from the supplied SVGs and checks the actual Flutter
layout with the bundled Inter font loaded, plus notch inset behavior.
Flutter/Dart SDKs are not installed here, so these widget/unit tests and
`flutter analyze` have not been run. Device behavior and pixel comparison
remain unverified.

With Flutter installed, run the existing setup if native runners are missing,
then `flutter pub get`, `flutter analyze`, and `flutter test`. On a device, scan
both code types in automatic/manual mode and from an image; verify one feedback
event, correct format/value, Open/Search, Copy, Save, rescan and theme changes.

Artwork regeneration: `python3 tool/scan_result_artwork/build_assets.py`
(requires Inkscape).
