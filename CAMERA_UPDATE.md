# Camera and automatic scanning update

## Implemented

- Shared camera chrome based on `design/scanner-camera-screen.svg`: black background, exact extracted import/close/flash icons, mint shutter ring, detection pill, mint page outline and corner markers. Camera preview is live; the sample paper/desk in the SVG is not rendered as a fake feed.
- Centered, snapping horizontal mode carousel. Swiping in either direction or tapping a visible mode selects Document, ID Card, QR Code or Barcode. The camera owner is stopped/disposed before the next mode starts.
- Unified Home scan session preserves the selected kind when saving. QR/Barcode return text results; Document/ID return processed pages and use their existing PDF/review flows.
- Document detection uses a 320-pixel-wide upright luminance sample, denoising, adaptive contrast levels, convex-hull quadrilaterals and actual edge-support checks. A featureless frame does not produce a fabricated rectangle.
- Auto is enabled by default and visibly marked. It requires a stable outline for 1.2 seconds plus a sharpness check. Loss of focus resets the stability timer without re-arming a captured page. Batch mode requires page removal before another automatic capture. Manual shutter remains available.
- Continuous autofocus/exposure where supported; tapping the preview targets focus/exposure with cover-fit coordinate mapping.
- Full-resolution captures are re-detected before cropping. A projective homography corrects perspective (replacing the previous bilinear warp). Output is capped at 2400 pixels on its long edge.
- Auto Enhance is enabled by default and can be toggled in the camera header. Processing includes a smooth local illumination estimate, bounded shadow correction, contrast cleanup and mild sharpening, with color retained. Processing runs off the UI isolate. Existing editor transformations do not implicitly reapply enhancement.
- ID mode checks card proportions, shows a card guide, and supports one/two sides. QR and Barcode use their respective decoding formats and differently shaped guides, with Auto/Manual read behavior.
- Image imports and file imports are wired. Document/ID file import accepts PDF/JPEG/PNG; PDF pages are rasterized without document-edge cropping. QR/Barcode file import accepts images for decoding.
- Switching away from a document session with captured pages is disabled until Done, avoiding silent loss. Existing home/empty-state changes remain included.

## Validation performed here

- Inspected the supplied SVG and rendered/extracted its control artwork.
- Checked local Dart imports, asset availability and lexical delimiter balance.
- Reviewed the camera/image APIs against their package documentation.
- Added `test/scanner_pipeline_test.dart` for dim/perspective detection, blank-frame rejection, capture focus gating, illumination cleanup, text/color preservation and projective mapping.
- Added `test/scanner_camera_shell_test.dart` for bidirectional mode scrolling and small-screen control interaction.

**Flutter/Dart SDK and phone camera hardware are not available in this environment. Compilation, Flutter tests, live camera behavior, performance and screenshot parity have not been verified here.** This is an implementation of similar scanning features, not a verified reproduction of CamScanner's proprietary detection/enhancement quality.

## Run before release

```sh
flutter pub get
flutter analyze
flutter test test/document_scan_test.dart test/scanner_pipeline_test.dart test/scanner_camera_shell_test.dart test/id_card_processing_test.dart test/code_result_card_test.dart
```

On Android and iOS, check light/dark desks, low contrast, shadows, skew, small text, portrait sensor rotation, focus, denied permissions/retry and background/resume. Verify Auto waits for stability, Manual does not capture by itself, Batch cannot duplicate a stationary page, mode switching releases the camera, and imports/save retain the correct document kind. Compare real captured documents before making a quality/parity claim.
