# Settings, Language and About App

The existing home Settings button now opens the supplied grouped settings design.
Language and About App open their respective new screens. About displays the
actual project version (0.4.0), not the design's illustrative version 2.4.1.
The open-source license page remains accessible from About.

Vibration and Beep switches persist in application-support app_preferences.json.
Successful document/ID-card camera captures and QR/barcode detections use these
preferences. Sound uses the platform system click; sound/haptics depend on device
support and system settings. They do not control the native camera shutter sound.

Language selection persists for all nine supplied choices. Settings and Language
labels are translated, with RTL layout for Arabic in these screens. Existing
scanner/editor/home content and the About descriptive body remain English; this
is not a complete application-wide localization release.

Share With Friend opens the native share sheet with recommendation text and the
store URL when configured. Rate Us, Privacy Policy, Terms and More Apps launch
configured HTTPS URLs. No publisher URLs were supplied in the design. Configure:

flutter run \
  --dart-define=APP_STORE_URL=https://YOUR-PUBLISHED-APP-URL \
  --dart-define=PRIVACY_POLICY_URL=https://YOUR-PRIVACY-PAGE \
  --dart-define=TERMS_URL=https://YOUR-TERMS-PAGE \
  --dart-define=MORE_APPS_URL=https://YOUR-PUBLISHER-PAGE

Replace these example values with real publisher URLs. Unconfigured links show
an availability dialog; the app does not invent legal policies or store listings.

Validation: inspected all three reference SVGs, reviewed navigation and feedback
hooks. Added persistence/platform-feedback tests and Settings navigation tests.
Flutter/Dart is unavailable in the editing environment; compilation, widget tests,
visual rendering and physical-device checks were not run. Run flutter pub get,
flutter analyze and flutter test. Verify toggles after restart, successful scan
feedback, language/RTL, support links, native sharing, About and licenses on-device.
