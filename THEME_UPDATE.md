# Light, Dark, and System appearance

Settings > Theme now provides System Default, Light, and Dark. The selection
is stored with the existing language, vibration, and beep preferences. System
Default follows device appearance changes while the app is running; explicit
Light and Dark choices override the device. Invalid or older settings default
to System Default. A failed save retains the last successful choice.

## Reference design

The uploaded Setting_page.svg and Theme_page.svg are retained in design/theme.
Theme illustrations, the settings badges, chevrons, and back arrow use the
original SVG paths, rendered at 4x resolution. Layout uses the supplied 375-point
reference spacing, rounded panels, and three theme cards. It adapts to smaller
screens, larger text, and the device's actual safe areas. Settings and Theme
omit the bottom navigation as in these two references; tapping the brand logo
returns from Settings, and Theme has the reference back arrow.

The references contain light-mode screens. Dark-mode colors use the navy tones
in the supplied dark illustration, with readable light foregrounds. Secondary
text, a few colored icon strokes, and camera-menu gradients were strengthened
where necessary for contrast. Icon geometry is unchanged. Native status bars
remain device-owned rather than reproducing the reference's sample time.

## Coverage

Theme-aware colors apply to Home, categories, Recent Files and selection,
settings/language/About, dialogs and sheets, scan results, document/ID previews,
crop/filter/size/rotation tools, OCR, signature controls, navigation, toolbars,
and loading/error states. Dark variants remove white baked-in UI backgrounds
from home/navigation/file artwork. Native dark splash colors are included.

Camera feeds, PDF paper, imported images, filter output, and signature ink keep
their content colors. The signature drawing canvas remains a light content
surface so black ink remains visible. Changing appearance does not recolor or
rewrite saved documents. All earlier fixes remain included.

## Validation

- Python contrast checks passed for the light/dark semantic text colors against
  surface, background, workspace, and selection colors (minimum 4.5:1), active
  controls (minimum 3:1), header labels, and camera-menu labels.
- All Dart application/test files passed syntax parsing and dynamic-const checks.
- All 47 new PNGs were decoded and checked for nonempty content. Source-derived
  theme illustrations and dark navigation/category artwork were visually checked.
- Flutter/Dart SDKs are unavailable here. Flutter analysis, widget tests, native
  execution, and device screenshot comparisons have **not** been run. Exact
  pixel matching on a device remains to be verified.

On a Flutter development machine:

```sh
python3 tool/test_theme_contrast.py
flutter pub get
flutter analyze
flutter test test/appearance_test.dart test/settings_screen_test.dart test/home_screen_test.dart test/shared_reference_ui_test.dart
```

Use the existing setup/build flow to regenerate native splash resources. Test
all three modes after restart, change device appearance while System Default
is selected, and inspect every screen with enlarged text. Check document and
signature previews to confirm their content colors remain unchanged.
