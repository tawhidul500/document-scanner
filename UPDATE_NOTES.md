# Document editor screens

Implemented the screens supplied in Document scanner & PDF Scanner 2 (Copy).zip in the existing document workflow:

- Share on a saved PDF opens document review. Edit opens the editor.
- Crop toolbar selection opens the Crop page, with a blue translucent selection and draggable corner brackets. Done applies the crop.
- Filters opens Filter, with No Filter, AddictiveBlue, AddictiveRed, Aden, and Amaro thumbnails plus a live strength slider. The same color matrix is used for preview and saved output.
- Size opens Resize, with Original Size, A4 Size, A5 Size, ID Card, and Legal in the bottom toolbar. The selected format is previewed and used for the edited page in PDF export. Original Size interprets image pixels at the review raster resolution of 144 dpi.
- Rotate opens the dedicated page with Rotate Left and Rotate Right at the bottom.
- Selected editor controls use blue highlights. Undo restores the previous image and paper size, retaining up to ten edit states.
- Each tool's Done returns to the editor. Editor Done saves the document. Back discards changes on the current screen.
- Option opens the Document Files bottom sheet with Rename, Download, and Export as PDF.

The source SVGs determine layout and controls; the user's actual document supplies the page content. Filter color treatments are implemented approximations of the supplied visual presets.

Validation: reviewed route/result types, temporary-file cleanup, preview/export filter consistency, size propagation, cancellation, and undo. Added image-processing and tool-screen regression tests. Flutter/Dart are unavailable here, so compilation, widget tests, and device screenshot validation have not run. Run flutter analyze and flutter test, then check crop gestures, saved PDF paper dimensions, and native sharing/export on Android/iOS before release.


## Convert / Recognize Text update

Mapped Document_page.svg to the document review Convert selection, Convert_page.svg to Recognize Text, and Convert_page-1.svg to its Save filename dialog.

Convert recognizes the current page with the native Latin-script OCR plugin, displays editable text, and provides loading, empty-result, failure, and retry states. Save opens the PDF dialog with an autofocus filename field, Cancel, and Ok. Valid filenames create a separate, named text PDF in Documents with the bundled Inter font. The original scan remains intact. Review uses the gray canvas and blue active Convert icon from the new reference.

Added recognition-screen and named-save regression tests; these have not run because Flutter/Dart is unavailable. Native OCR and PDF output still require device validation. Dependency and native runner setup notes were updated in PLATFORM_SETUP.md.


## Signature flow update

Mapped the new references to the document's Sign action:

- Document_page.svg: blue active Sign control.
- Add Signature_page.svg: Add Signature page with Sign and Gallery buttons.
- Edit Page/Signature Draw.svg: drawing canvas with Sign here placeholder, undo, redo, confirmation checkmark, stroke weight, and horizontal color palette.
- Edit Page/Signature Active.svg: movable signature on the actual page with remove, rotation, and resize handles, pinch/rotate gestures, color palette, and stroke weight control.

Done composites the signature at the chosen position into the current page and saves the document through the existing PDF persistence flow. Back discards staged signature changes. Gallery imports preserve transparency; opaque backgrounds remain part of the imported image. For imported images the slider adjusts opacity and selecting a color applies a tint. A signature can be removed and replaced before Done. The page preview and export use the same placement painter, and no selection borders or handles are included in the saved page.

Added drawing undo/redo, confirmation, and signature-bounds regression tests. Source structure and archive checks were performed; Flutter compilation, tests, gesture behavior, gallery permission/cancellation, and saved-image fidelity require device validation because the SDK is unavailable here.


## Custom ID card camera and preview

Both Home ID Card and the camera action popup now launch the supplied ID camera directly. Implemented the One Side / Both Sides states, front/back prompts, card corner guide and scan band, blue shutter, Auto/Manual, flash, gallery, capture thumbnail/count, and preview arrow. Capture limits and ordered front/back handling are enforced. Camera images are cropped to the visible card guide before optional edge correction; imported images use document edge processing.

The ID Card Image Preview displays the actual saved PDF. New captures place one or both sides together on a single A4 page. Option supports rename/download/export. Reopened older multi-page ID files retain all pages in a swipeable preview.

Added guide geometry, crop-output, and one-page PDF regression tests. Source delimiter and archive integrity checks passed; Flutter SDK is unavailable, so compilation, automated tests, camera crop alignment, native PDF rendering, and on-device interaction validation are pending.
