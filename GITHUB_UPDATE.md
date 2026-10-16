# Push version 0.5.0+6 and build on GitHub

Repository: https://github.com/tawhidul500/document-scanner

This update was prepared against main commit
`50d1d21bfbba110b6d987fe1493b4c1049a46aa3`.
It retains the existing scan temporary-directory, signature touch-down, camera
semantics, test I/O, analyzer, and ML Kit R8 fixes.

## Push with Git

Use Git Bash on Windows, or a terminal on macOS/Linux. Sign in with your Git
credential manager or GitHub Desktop as an account with write access to the repository.
Do not paste credentials into source files or chat.

The delivered ZIP includes a complete `document-scanner/` source folder and a
`document-scanner-update.patch` alongside it. Extract the ZIP, open a terminal
in the extracted folder (the one containing the patch), then run:

```sh
git clone https://github.com/tawhidul500/document-scanner.git document-scanner-repo
cd document-scanner-repo
git switch main
git pull --ff-only origin main
git apply --check --index ../document-scanner-update.patch
git apply --index ../document-scanner-update.patch
git diff --cached --stat
git commit -m "Update scanner UI, localization, onboarding and document actions"
git push origin main
```

The patch includes binary artwork and removal of six superseded splash files.
It applies all application files at the repository root. Do not upload the source
ZIP itself or nest the whole project under another repository folder.

If the check fails because the repository has changed, stop before applying and
reconcile those changes; do not force-push or reset another person's work. If main
is protected, create a new branch from the updated main before applying the patch,
push that branch, and merge a pull request before building main.

If Git asks for your commit identity, configure your own name and GitHub email in
this checkout. If authentication fails, sign in through your Git credential manager
or GitHub Desktop and retry the normal push.

## Build after pushing

Open https://github.com/tawhidul500/document-scanner/actions/workflows/build.yml

Select **Run workflow > main > target: android > Run workflow**.
After the Android job succeeds, open the run and download
**android-development-signed-apk** from Artifacts. Extract it to get
`document-scanner-android-test.apk` and `SHA256SUMS.txt`.

The app version is 0.5.0 and Android build number is 6. No remote build is started
by a push. The existing workflow name and Flutter 3.47.7 pin are retained.
The workflow now defaults to Android, with iOS or both available as explicit choices.

The APK is development-signed. A fresh CI runner can produce a different development
key, so installing over an older test APK may fail. Keep the same signing key for
repeatable in-place updates; do not uninstall a copy containing important local
scans without exporting them first.

No APK has been built in this editing session. Flutter analysis, widget tests, and
APK compilation are required gates in the workflow. The source package and patch
are prepared for that build, not a claim that those gates have passed.

Official GitHub workflow instructions:
https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow
