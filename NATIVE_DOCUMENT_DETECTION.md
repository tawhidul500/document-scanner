# Native document edge detection

The app keeps its existing scanner camera, green outline, Auto/Manual control,
flash, enhancement, batch capture and document editor. `document_scan` is pinned
to 0.3.1 as a headless detection dependency: OpenCV on Android, Apple Vision on iOS.

## Pipeline

- Feed YUV420 planes with their strides on Android and BGRA on iOS.
- Rotate frames into the same portrait coordinate system used by the preview.
- Run one detection at a time, at most about 6.7 requests/second. Native work
  detects document corners; the existing small luminance sample measures focus.
- Validate normalized clockwise convex corners and reject tiny/full-frame quads.
- Smooth the displayed outline, snapping when a different document appears.
- Keep auto-capture tied to raw corners, focus quality, a 1.2-second stable hold,
  and all four corners inside the visible cover-fitted preview. Smoothing does
  not conceal hand movement from the capture decision.
- Capture through CameraController.takePicture. Detect the captured original
  file again, never reuse preview corners for the final crop. Existing isolate
  processing applies the perspective transform and enhancement. Output retains
  the app's existing 2400-pixel maximum dimension, not the preview resolution.
- If still detection fails, keep the complete image (without automatic crop)
  available through Edit > Crop. Manual shutter remains available when live
  detection cannot find the page. Imported JPEG/PNG documents use native detection
  too; PDF imports keep their original page bounds.
- Camera restarts, focus changes and capture invalidate old detections. Still
  processing waits for an in-flight frame to finish. Batch capture still requires
  page removal before another automatic capture.

ID cards share the upgraded live outline, while retaining their existing
card-specific aspect checks, full-photo processing and two-side workflow.

## Validation and build

Seven Python checks pass, as do relative import and integration checks. Added
Flutter tests cover normalized geometry rejection, portrait rotation, smoothing,
and ensuring raw motion blocks capture. Flutter/Dart and mobile SDKs are not
installed in the editing environment: dependency resolution, Flutter analysis,
widget tests, native compilation and device accuracy remain unverified.

Run the existing workflow or `python3 tool/build.py apk` in a Flutter environment.
Retain the resolved pubspec.lock after a successful build. The existing platform
setup already configures camera permissions, Android minSdk 24 and iOS 15.5.
Native OpenCV adds binary size to Android builds.

Before release, test real devices with 90- and 270-degree camera sensors, portrait
orientation, camera background/resume, manual capture, auto capture, batch page
removal, gallery import, ID front/back, shadows, skew, glossy paper, white pages
on light backgrounds and pages partly outside the visible preview. Compare live
corners and final crops. CamScanner-equivalent accuracy is not claimed without
these tests and device-specific tuning.

API sources checked during implementation:
https://pub.dev/packages/document_scan
https://pub.dev/documentation/document_scan/latest/document_scan/DocumentDetector-class.html
https://pub.dev/documentation/document_scan/latest/document_scan/DocumentCorners-class.html
https://pub.dev/documentation/document_scan/latest/document_scan/ScanInput/ScanInput.yuvFrame.html
https://pub.dev/documentation/document_scan/latest/document_scan/ScanInput/ScanInput.bgraFrame.html
