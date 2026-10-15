# Android and iOS setup

Use current stable Flutter (at least 3.44.0 / Dart 3.12), Java 17+, and Android SDK. On macOS, install Xcode and its command-line tools for iOS.

If native runner folders are not included, run `python3 tool/setup.py`. The script preserves the authored Dart files, generates both runners, applies permissions and minimum versions, resolves packages, generates native splash resources, and runs analysis/tests. The setup is safe to rerun with existing runners. For complete builds, use tool/build.py as described in README.md.

## Platform prerequisites applied by setup

- Android: minimum SDK 24, camera permission, optional camera hardware feature.
- share_plus: Android Gradle Plugin >=8.12.1, Gradle >=8.13, Kotlin >=2.2.0, Java 17.
- iOS: deployment target 15.5 (conservative baseline for the selected plugin set), camera usage description, mixed localizations.
- CocoaPods: use_frameworks! for printing; use current stable Flutter's generated integration.
- No broad storage permission is requested. Download uses a system file-save dialog.
- Production: replace `com.example.pdf_scanner` with your own application ID/bundle identifier, configure signing, and use a production launcher icon before publishing.

## On-device acceptance checks

1. Cold launch: native logo, Flutter splash, then Home; no camera prompt at launch.
2. Document: capture two pages, adjust crop, finish; PDF opens and survives a restart.
3. ID Card: capture front and back; both pages appear in one PDF.
4. Cancel native scanning: return without creating a file.
5. Deny camera permission: actionable error; granting access in device settings permits retry.
6. QR and barcode: one result per scan, show decoded value, cancel or save, copy Unicode text.
7. Rename: blank/path-like names rejected; saved name survives restart.
8. Download: save via system picker; cancellation does not display success.
9. Share: verify filename/content on Android, iPhone and iPad popover.
10. Delete: cancel retains file; confirm removes file and updates category counts.
11. Search: case-insensitive matching; categories filter correctly; Home returns to top.
12. Camera action menu: verify all five actions, dimmed background, X, outside tap and system Back.
13. Import PDF: valid PDF imports, cancel adds nothing, non-PDF content is rejected; restart retains imported file and rename/delete leave the original untouched.
14. Check 375 x 813 and small-phone layouts, large text, camera app background/resume, and notches.

## Scanner limits

Document and ID scanning use the custom camera. ID mode caps captures at one or two sides according to the selected mode, accepts gallery images, and puts both sides on one PDF page. QR/barcode mode stores decoded content as UTF-8 TXT. Convert performs Latin-script OCR on the current document page and saves recognized text to a new PDF.


## Version 0.4.0 custom document camera acceptance

For existing iOS runners add NSPhotoLibraryUsageDescription: Choose document images to scan. The custom camera disables audio; document capture does not use the microphone.

1. Both Home Document and the camera-menu Documents action must open the custom camera immediately.
2. On supported Android and iOS devices, confirm the blue edge outline tracks the real page with upright and rotated device positions. Single capture must produce the correctly oriented cropped page.
3. Auto capture must wait for about 1.2 seconds of stable edges, reject blank scenes and avoid taking repeated copies of an unchanged page. Remove the page for at least three analysis frames to re-arm.
4. Manual shutter must work without detected edges. Check manual crop adjustment on the review screen.
5. Batch mode: take several pages, use Done, swipe through them, check counter and PDF order. Single mode: one capture opens review.
6. Exercise flash support, denied permission, app background/resume, camera cancellation and gallery cancellation. Android activity destruction while the photo picker is open is not covered by automated tests; verify draft handling on target devices.
7. Review: share PDF, export PDF, export current JPG, crop, rotate, draw/undo signature, rename, add/delete pages and restart the app to confirm the resulting PDF persists.
8. Deny storage/full-disk operations and verify save errors can be retried before leaving review. Stress test 50 pages on a low-memory device; PDF generation currently loads compressed page data into an isolate.


## Text recognition setup

- Pinned `google_mlkit_text_recognition: 0.16.0` to retain the project’s Dart 3.10 baseline. See https://pub.dev/packages/google_mlkit_text_recognition/versions/0.16.0.
- Native OCR runs on Android/iOS. The plugin requires Android compile/target SDK 35 or newer and iOS 15.5 or newer, Xcode 15.3+, Swift 5, and 64-bit architectures. The existing minimum Android SDK 24 satisfies its minSdk 21 requirement.
- Run `flutter pub get` after updating; for an existing iOS runner, update Pods and verify every target is iOS 15.5+ with armv7 excluded. The setup script applies these settings for generated runners.
- This build uses the Latin recognizer, matching the supplied English designs. Other recognition scripts require their native model dependencies and script selection.
- Device checks: Convert a real page, correct OCR text, open Save, reject an empty or path-like name, cancel without creating a file, then save and reopen the new text PDF. Confirm the source scan is unchanged, no-text and recognition errors are actionable, long results scroll, and the filename dialog stays visible above the keyboard.


## Signature acceptance checks

1. Review > Sign opens Add Signature with Sign and Gallery controls; the source review Sign action is blue.
2. Sign opens the drawing canvas. Draw several strokes, undo/redo, change color/weight, and confirm. Confirm stays disabled when no strokes exist.
3. Move the resulting signature, use rotation and resize handles, and test two-finger scale/rotation. Ensure it stays within the page.
4. Remove a signature, import a transparent PNG from Gallery, cancel the picker, and verify denied photo access has an actionable error. Imported photos keep their original background.
5. Done saves the exact placement without selection handles; reopen/share the PDF to verify. Back on either screen must leave the source document unchanged.
6. Check small phones, long/thin signatures, portrait/landscape page images, large text settings, and available-memory behavior on high-resolution scans.


## ID camera acceptance checks

1. Home ID Card and camera popup ID Card open the same custom camera with no intermediate native-scanner dialog.
2. One Side: capture/import the front, confirm count 1, tap the enabled preview arrow, and verify one card on the saved page.
3. Both Sides: capture/import front, confirm the Back label/prompt, turn the card over, capture back, confirm count 2, and preview both sides on one page. The preview arrow stays disabled after only the front.
4. Auto requires a stable, card-shaped detected edge inside the guide. Move the card away between front/back; use Manual if edge detection cannot find the card. Confirm captured cropping aligns with the guide on each target device.
5. Test flash unavailable/denied camera, gallery cancellation, background/resume, one-to-both mode switch, and discard confirmation. Confirm no more than the selected side count can be captured.
6. Preview, rename, export, restart, and reopen the ID PDF; check front/back order. Older multi-page ID PDFs should remain swipeable in preview.
