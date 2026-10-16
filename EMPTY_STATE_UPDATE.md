# Empty home reference update

The supplied `design/home_empty_reference.svg` is the source of truth.

- Replaced the generic bottom bar with its actual curved cutout, blue camera button, custom Home/Settings icons, labels and original composited shadows.
- Extracted separate 4x components for the masthead, category tiles and empty illustration. Native tap targets retain search, scanning, folder browsing, Home and Settings behavior.
- Matched section spacing and removed See all when no files exist.
- Folder counts remain live (zero on an empty install); sample counts in the design are not hardcoded.
- System time, status icons and bottom safe insets remain device-owned. The design's content coordinates assume a 44-point top inset at 375-point width.
- Navigation scales proportionally with width; content scrolls on smaller devices.

## Validation

Rendered and inspected reference artwork; checked extracted assets and Dart delimiter balance. Added a widget regression case for empty-state copy, counts, camera menu and Settings navigation. Flutter/Dart SDK is unavailable in the editing environment, so compilation, widget tests and device screenshot comparison have NOT been run. Pixel-perfect runtime parity is not yet verified.

Run with the project's Flutter version:

```sh
flutter pub get
flutter analyze
flutter test test/home_screen_test.dart test/camera_action_menu_test.dart
```

Artwork can be regenerated using `python tool/home_artwork/extract.py`, then `node tool/home_artwork/render.cjs` (requires sharp). No new app runtime dependency was added.

## App-wide follow-up

All document-list empty states (Home, all four category folders and their subfolders, Recent Files and the file browser) now use `ScanEmptyState`. Search results use the same illustration and typography with search-specific copy.

Home, category folders, Recent Files, the file browser, Settings, Language and About use one shared reference navigation component. Settings has a blue active icon/label; file-list routes use neutral tabs. Home returns to the root route, and the camera returns home and invokes the existing scan menu. Selection mode keeps Move/Share/Merge/Delete. Editor and selection toolbars share the reference's white surface and upward shadow while retaining their specialized actions.

Follow-up verification: all Dart files passed lexical delimiter checks and shared artwork assets were generated successfully. These checks do not replace compilation or Flutter widget tests; the SDK remains unavailable.
