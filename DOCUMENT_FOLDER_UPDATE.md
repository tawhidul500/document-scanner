# Document folder update

The Document tile under My Documents now opens the supplied blue-header folder
browser. Other category browsers and the prior QR/barcode implementation remain.
The list uses real stored documents, with file sizes, dates and empty/search states.

Implemented:
- Create and rename subfolders; open a subfolder and return to Document.
- Search the current folder.
- Long-press any item to enter selection; select/deselect all visible items.
- Per-file Rename, Download, Delete and Select menus.
- Per-folder Rename, Delete and Select menus.
- Move selected files between Document and its subfolders.
- Native multi-file share sheet, with platform-provided apps/contacts.
- Merge two or more PDFs into a named PDF in the current folder.
- Confirmed deletion, including selected folders and their contained files.
- Disabled bulk actions for empty selection; folder selections support deletion.

Folder names and membership persist in scans/folders/index.json, independently
of existing scan records. Existing files initially appear at the Document root.
No sample files or contacts are inserted. This app currently stores documents as
PDF; the sample JPG/PNG rows in the design are not fabricated.

Merge uses the existing printing rasterizer at 144 DPI, capped at 100 pages.
Original PDFs remain unchanged. The merged PDF contains page images, so source
PDF text layers, links and form fields are not retained in the merged copy.

Validation: inspected all 15 supplied SVG designs, reviewed routes and persistence,
and added document_folders_test.dart covering persistence, duplicate folder names,
root moves and compatibility with scan metadata. Flutter/Dart is not installed in
the editing environment, so compilation, widget tests and device checks could not
be run. Run flutter pub get, flutter analyze and flutter test before release.
On-device checks: create folder, move files, restart, open folder/file, rename,
search, select all/none, share, merge, download, cancel/confirm deletion, and back.
