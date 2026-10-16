# Reference file thumbnails

Source: `design/file_thumbnail_reference.svg` (the latest supplied Home SVG).

- Extracted the exact PDF, image and TXT/document artwork, including tile backgrounds, rounded corners, outlines and badge lettering, at 4x density.
- Preserved the SVG root's `fill="none"` inheritance so the purple image artwork remains an outline.
- Added one shared `FileThumbnail` component used by Home, Recent Files, the file browser, every category folder and its subfolders.
- PDF files use the red PDF artwork; image formats use the purple image artwork; text/code files use the blue TXT artwork. The thumbnail describes the real saved extension rather than a sample filename from the mockup.
- Added the source's blue/green/purple/orange folder artwork to subfolder rows, selected by category.
- Reused the exact three-dot menu artwork in all file rows. Matched the source thumbnail footprint, thumbnail-to-title gap, Home row pitch and file typography.
- File opening, selection, counts, naming and menu actions remain native and data-driven. Previous empty-state, navigation and camera work is included.

Validation: rendered and visually inspected extracted artwork; checked asset registration, shared-component call sites, local imports and source delimiter balance. Flutter is unavailable here, so no build or app screenshot comparison was performed. Pixel-perfect runtime parity remains unverified.

Regenerate assets with `python tool/file_artwork/extract.py` and `node tool/file_artwork/render.cjs` (requires sharp). No Flutter runtime dependency was added.
