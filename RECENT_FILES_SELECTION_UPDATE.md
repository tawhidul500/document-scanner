# Recent Files selection

Home > Recent Files > See all now supports:
- Select files from the header, long-press a file, or choose Select in its menu.
- Checkboxes, selected-row highlighting and selected-file count.
- Select all / Deselect all for the visible category/search results.
- Move, Share, Merge and Delete in the bottom selection toolbar.
- Cancel selection with the close button or the device Back button.
- Filter/search changes clear selection; deleted files are removed from selection.

Move is available when selected files belong to one category, because folder
indexes are separate for Document, ID Card, QR Code and Barcode.
Share and Delete can operate on files from multiple categories.
Delete asks for confirmation and removes folder membership for deleted files.
Merge accepts at least two PDF/text files and retains the originals. Mixed-category
merges are saved under Document; same-category merges keep their category.
PDF merging follows the existing raster-based workflow, with a 100-page limit.

Previous navbar, scan beep/vibration and About App changes are included.

Verification: modified Dart files parsed without syntax errors; the native setup
regression check and ZIP integrity/difference checks passed. Added Flutter tests
cover selection entry points, filters/search, live deletion, cancel/confirm
deletion, moving and text-to-PDF merging. Flutter is unavailable here, so these
widget tests, type analysis, native compilation and on-device checks are pending.

On a Flutter-equipped machine:
  flutter pub get
  flutter analyze
  flutter test test/recent_files_screen_test.dart test/recent_files_selection_test.dart
  flutter run

If upgrading from a version before the scan-feedback fix, stop the app and perform
a full rebuild so the audio/vibration plugins are registered.
