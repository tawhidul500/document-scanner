# ID-specific capture limits and preview

- One side permits one image; Both side permits two. Camera capture, appending processed images and file imports enforce the selected limit. Capture/import controls disable once all requested sides exist.
- ID gallery imports choose one image at a time for the current side. Multi-image picking remains available only for document batches. ID file imports accept JPEG/PNG rather than multipage PDFs, with an additional PDF rejection guard.
- Both-side mode requires the back before Done. New ID side images are stored durably with the PDF, preserved on rename/reopen and removed on deletion. Storage rejects a third side before writing content.
- New ID previews show separate labeled Front side/Back side card surfaces in ID-1 proportions (85.6:54), with pinch zoom and no stretching. Portrait captures/imports rotate into landscape card orientation.
- PDF exports place the one/two sides at 85.6 × 54 mm on one A4 sheet instead of enlarging them to page width.
- Older scans without separate side images retain their existing PDF sheet preview. Generic edits replacing an ID PDF invalidate old side previews so the app never displays stale original sides.
- Added storage/reopen/rename/deletion/third-side regression coverage and a card-preview widget test.

Validation performed: local import and source delimiter checks. Flutter is unavailable here, so compilation, widget tests, platform pickers and real-camera behavior remain unverified. Run `flutter analyze` and `flutter test test/id_card_storage_test.dart test/id_card_sides_preview_test.dart test/id_card_processing_test.dart test/document_store_test.dart` before device testing.
