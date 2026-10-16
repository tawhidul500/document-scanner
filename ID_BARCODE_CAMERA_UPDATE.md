# Shared ID camera and barcode guide correction

- ID Card uses the shared camera and opens with ID Card centered and selected directly above the shutter. The same Auto/Manual, Auto Enhance, flash, image/file imports and swipeable mode strip are retained.
- ID mode uses One side/Both side labels. One side captures one card and opens its preview automatically; Both side supports front/back capture and Done. Document retains Single/Batch labels. The status explains which side to align.
- ID adaptive detection accepts landscape and portrait cards. Auto capture still requires a stable, sufficiently sharp outline. Still-photo card boundaries are re-detected before perspective correction and automatic enhancement, avoiding reuse of preview coordinates when the camera fields of view differ. If no card boundary is found, manual capture retains the visible guide fallback.
- Document, ID Card, QR Code and Barcode continue to share the swipeable mode flow and release camera ownership before switching. QR's layout, mint guide and scanning animation are unchanged by this follow-up.
- Barcode's previously rectangular mask now uses a rounded opening. Blue corner strokes are inset by half their thickness; the rectangular decoder ROI is inset inside the rounded corners. One geometry object defines the opening, strokes and scan region, preventing mismatched corner bounds.
- Added regression tests for initial ID selection/controls and barcode guide containment at several phone widths.

Validation here: checked local imports and source delimiter balance. Flutter and camera hardware remain unavailable, so the added tests, builds and device behavior have not been run. Run `flutter analyze` and `flutter test test/scanner_camera_shell_test.dart test/barcode_geometry_test.dart test/scanner_pipeline_test.dart test/id_card_processing_test.dart` with the project's Flutter SDK, then verify live ID and barcode capture on Android/iOS.
