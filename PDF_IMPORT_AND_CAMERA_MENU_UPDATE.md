# PDF import and camera menu update

- Camera > Import PDF opens the existing document review screen, with Option,
  Share, Edit, Convert (OCR), and Sign. Edit includes crop, filters, paper size,
  rotate, and undo. Imported documents use this screen again when opened from
  Home, Recent Files, or document folders.
- The imported original is copied into app storage. Merely opening, viewing,
  sharing, or exporting does not rewrite the PDF. Page images are held in a
  temporary editing directory which is removed when review closes.
- Edits use the existing image-based document workflow, including its 50-page
  editing limit. Saving an edit renders the PDF as page images; original page
  dimensions are used unless the user selects another paper size.
- The underlying navigation camera artwork, ring, and shadow are hidden while
  the camera menu is open. Only the menu's close button remains. The camera
  returns after the dismissal animation finishes.
- Earlier navigation corner, scan feedback, About, and Recent Files selection
  changes are included.

## Verification

Dart syntax parsing and archive integrity checks passed. Flutter and Dart SDKs
are unavailable in the editing environment, so Flutter analysis, widget tests,
and native device checks have not been run. Regression tests cover the import
route, document actions, reopening, original-file preservation, picker cancel,
empty PDFs, and camera visibility through menu dismissal at multiple widths.

On a Flutter development machine, run setup as documented in README.md, then:

```sh
flutter pub get
flutter analyze
flutter test test/pdf_import_review_test.dart test/home_screen_test.dart test/camera_action_menu_test.dart test/shared_reference_ui_test.dart
```

On a device, import a multipage PDF, edit a page, sign it, run OCR, export/share,
and reopen it from Recent Files and Documents. Open and close the camera menu
using the X, an outside tap, and Back to check the camera artwork restoration.
