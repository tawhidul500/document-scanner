# QR and barcode screens

Implemented the four supplied SVG references in `lib/features/scan/code_scanner.dart`.
Both the home shortcuts and camera popup already route to CodeScanner and now use
these screens. QR scanning has blue square corners and an animated scan band;
barcode scanning has a wider frame with rounded blue corners. Camera imagery is
live; the sample codes in the design are not embedded in the scanner.

Controls: flash (when available), gallery image decoding, zoom, back/close.
Detection pauses the camera and presents the matching result card. Close or system
back resumes scanning. Copy uses the clipboard. Open launches HTTP(S) links and
explains when a payload is plain text. Save returns the payload to the existing
local document store; the previous duplicate confirmation dialog was removed.
Camera failures have a retry action, and gallery failures report a message.

Added `url_launcher: ^6.3.2`; run `flutter pub get` before building.
Original platform setup instructions still apply (this archive is a Flutter
source project without generated Android/iOS host folders).

Validation: reviewed the supplied SVGs, route wiring, save integration and plugin
API documentation. Added `test/code_result_card_test.dart` for both result types,
actions and long payloads. Flutter/Dart SDK is unavailable in the editing
environment, so compilation, widget tests and device camera tests were not run.

Before release run:
- flutter pub get
- flutter analyze
- flutter test
- On a physical device, check both entry points, QR/barcode recognition, flash,
  zoom, gallery (valid code, wrong type, no code, cancellation), permission denial
  and retry, background/resume, result close/back, Open/Copy/Save.
