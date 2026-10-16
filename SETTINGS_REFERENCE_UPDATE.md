# Settings reference update

The settings screen now uses the icon paths from the supplied Setting_page.svg.
SVG extraction preserves inherited fill="none", preventing black interiors in
outlined glyphs. Light artwork retains the reference colors; dark artwork uses
matching dark backgrounds and brighter strokes. System appearance resolves the
same variants through the current Flutter theme.

Cards use the reference radius, inset dividers, subtle shadow and light background.
Rows retain the previous update's 14 px bold labels and 13 px descriptions, with
56 px minimum height and content-driven expansion. The corrected 84 px settings
banner and enlarged typography remain. Content scrolls on smaller displays.
The supplied SVG's smaller typography and simulated OS status bar are intentionally
not copied: the requested updated typography and real device status bar are used.

Validation: seven Python checks pass. Icon assets were rendered and visually
checked in both appearances. Flutter compilation, widget tests and full-screen
pixel comparison require Flutter, which is not installed in this environment.

Regenerate settings icons:
  python3 tool/theme_artwork/build_settings_icons.py
  node tool/theme_artwork/render_settings_icons.cjs
The Node renderer requires sharp.
