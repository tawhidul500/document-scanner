# Document Scanner

Flutter document, ID card, QR code, and barcode scanner. Current update: **0.5.0+6**.

## Build the Android APK on GitHub

1. Open [Verify and build mobile apps](https://github.com/tawhidul500/document-scanner/actions/workflows/build.yml).
2. Click **Run workflow**, choose **main**, and leave **target = android**.
3. Click **Run workflow** and wait for the Android job to finish.
4. Open the completed run and download **android-development-signed-apk** from Artifacts.
5. Extract the download and install `document-scanner-android-test.apk` on your Android device.
   `SHA256SUMS.txt` contains the APK checksum.

The workflow is manual; pushing this update does not start an APK build. Choose
`ios` or `both` only when those outputs are needed. The iOS artifact is an unsigned
app ZIP and is not installable on a device.

The build uses the repository's existing Flutter 3.47.7 pin and Java 17. It generates
missing native runners, configures Android/iOS requirements, resolves dependencies,
regenerates the native splash, runs `flutter analyze` and the complete Flutter test
suite, then builds. The Android job also runs the localization and palette contrast
checks. A failing check stops the build; no placeholder APK is uploaded.

Android builds currently use Flutter's generated development signing and the existing
`com.example` organization setting. Production distribution requires a stable application
ID and release signing. Installing over an earlier APK requires the same application ID
and signing key; an APK from a fresh CI runner may have a different development key.

## Included in this update

- First launch: select a language, then tap Next to save it and open Home. Later launches
  use the saved choice. Existing valid language preferences are retained.
- App text in nine languages, including Arabic right-to-left layout.
- Light, dark, and system appearance, using the supplied design artwork.
- New supplied opening animation and removal of the previous splash artwork.
- Shared file actions for Recent and folders: document actions, preview, print, share,
  and export. Document tools include Edit, Sign, OCR, Share, and Export.
- Imported PDFs open in document review; existing PDFs can be reopened for editing.
- Recent > See all supports the same selection controls as folders.
- QR/barcode result redesign, scan beep and vibration, document/ID camera improvements,
  and corrected menu close buttons and navigation corners.
- About no longer displays the open-source licenses section; bundled font license files remain.

See the feature-specific `*_UPDATE.md` files, `FIRST_LAUNCH_LANGUAGE.md`,
`SCAN_FEEDBACK_FIX.md`, `SCAN_RESULT_REDESIGN.md`, and `SPLASH_REPLACEMENT.md` for details.

## Local build

Install Flutter 3.47.7 and the platform SDK, then run from the repository root:

```sh
python3 -m unittest discover -s tool -p 'test_*.py' -v
python3 tool/build.py apk
```

Output: `dist/document-scanner-android-test.apk`.

Other targets:

```sh
python3 tool/build.py check
python3 tool/build.py ios   # macOS + Xcode; unsigned app ZIP
python3 tool/build.py ipa   # macOS + Xcode; Apple signing must be configured
```

Missing native runners are generated in a temporary folder before copying them into
the project. Existing app source and native runners are preserved. ML Kit non-Latin
R8 warning rules are added without discarding existing ProGuard rules. See
`PLATFORM_SETUP.md` for device permissions and platform requirements.

`pubspec.lock` is not yet committed. The Android workflow uploads the resolved file as
**android-resolved-lockfile**. Retain and commit it after a successful build to lock
transitive dependency versions.

## Verification status

Preparation checks cover Dart syntax, local import/asset paths, translation coverage,
color contrast, Python syntax, workflow structure, and patch application against the
repository baseline. These checks do not compile Flutter or test camera hardware.
Flutter analysis, widget tests, and APK compilation must pass in GitHub Actions.
Test camera capture, beep/vibration, import/export, printing, and signing on a physical
Android device after downloading the APK.

See `GITHUB_UPDATE.md` for the exact push procedure and `BUILD_REPORT.md` for earlier
build-environment notes.
