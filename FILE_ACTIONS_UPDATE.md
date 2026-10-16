# File actions update

- Tap any saved file from Home Recent, Recent > See all, a category folder, or a
  subfolder to open the shared actions sheet: Open document actions, Preview,
  Print, Share, and Export.
- Open document actions exposes Edit, Sign, OCR, Share, and Export in the document
  review toolbar. Review > Option also provides Print and Share.
- Document and ID card PDFs use the existing editor. QR/barcode text scans create
  a separate PDF in Documents before editing; the original TXT is preserved.
  The sheet explains this before the user opens the editor. Conversion must
  render successfully before the PDF copy is saved.
- Print, Share, and Export work directly on original PDFs without rasterizing
  or rewriting them. Printing a text file generates an in-memory PDF and does
  not add a saved copy. Cancelling the print dialog does not change the file.
- Existing three-dot menus also expose Print, Share, and Open document actions.
  Preview screens provide Option to access the same menu. Returning from editing
  refreshes previews. Selection mode continues to select files on tap.
- PDF imports still enter document review directly. Editing retains the existing
  50-page limit; direct print/share/export do not use that limit. OCR uses the
  existing current-page Latin-script recognizer.
- New menus use the app's light/dark palette, scroll with larger text, and respect
  safe areas. The five document toolbar actions wrap on narrow screens.

## Verification

Passed in this environment:

- Syntax parsing for all 68 Dart application and test files.
- Existing theme and code-result contrast checks (3 Python tests).
- ZIP integrity and cumulative-source comparison before packaging.

Regression tests added/updated for file opening from all four entry points,
PDF/ID and QR/barcode document access, original-file preservation, direct printing,
large-text light/dark menus, and keeping camera PDF imports in the editor.

Flutter/Dart SDK and native runners are unavailable in this environment. Flutter
analysis, widget tests, compilation, and native print/share/export device tests
have not been run. Run `flutter analyze` and `flutter test` in the configured
Flutter project, then verify native dialogs on Android and iOS. This deliverable
is the updated source ZIP, not a built APK/IPA.
