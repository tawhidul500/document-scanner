# ID Card, QR Code and Barcode folders

All four My Documents tiles now open the shared folder screen, filtered to their
own ScanKind. The title follows the selected category. QR/barcode text files show
blue text-document icons, names without the .txt suffix, and size/age metadata.
ID Card PDFs retain red PDF icons. Lists contain actual saved files, not samples.

The Document selection implementation is reused directly: long press or Select
from a file menu, selection count, checked row styling, Select all, Deselect all,
close selection and disabled actions for empty selection. All categories support
search, subfolders, rename, download, move, native share and confirmed deletion.
Folder selections support Delete, matching the Document flow.

Folder metadata is isolated by category. The existing Document index path remains
unchanged. Cross-category moves are rejected. Existing scans initially appear in
their category root. ID Card opening still uses the existing ID Card preview;
QR/barcode text opening still uses the existing readable/copyable content preview.

Merge accepts two or more PDF/text files and creates a named PDF in the current
category/folder, preserving originals. Text payloads become PDF text pages; PDF
inputs are rasterized using the existing 144-DPI workflow, so their text layers,
links and forms are not retained in the merged copy. Inter is embedded for text.

Validation: reviewed all six supplied SVGs, shared navigation and category filters.
Added widget tests for identical selection transitions across all four categories,
and persistence tests for isolated folder metadata and cross-category rejection.
Flutter/Dart is unavailable here; tests, compilation and device checks were not run.
Run flutter pub get, flutter analyze and flutter test before release.
