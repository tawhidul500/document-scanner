"""Validate runner configuration against fixtures without requiring Flutter."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

class SetupTest(unittest.TestCase):
    def test_existing_runners_are_configured_idempotently(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tool').mkdir()
            shutil.copy2(Path(__file__).with_name('setup.py'), root / 'tool/setup.py')
            files = {
                'android/app/src/main/AndroidManifest.xml': '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="pdf_scanner"/></manifest>',
                'android/app/build.gradle.kts': 'android { defaultConfig { minSdk = flutter.minSdkVersion } }',
                'android/settings.gradle.kts': 'plugins { id("com.android.application") version "8.9.0" apply false\n id("org.jetbrains.kotlin.android") version "2.1.0" apply false }',
                'android/gradle/wrapper/gradle-wrapper.properties': 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.12-all.zip',
                'ios/Runner.xcodeproj/project.pbxproj': 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;',
                'ios/Podfile': "# platform :ios, '13.0'\ntarget 'Runner' do\nend\npost_install do |installer|\ninstaller.pods_project.targets.each do |target|\nflutter_additional_ios_build_settings(target)\nend\nend\n",
                'lib/main.dart': '// Authored code must survive',
                'README.md': 'Authored README must survive',
                'bin/flutter': '#!/bin/sh\nexit 99\n',
            }
            for relative, content in files.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            (root / 'bin/flutter').chmod(0o755)
            for relative in ['ios/Runner/Info.plist', 'ios/Flutter/AppFrameworkInfo.plist']:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(plistlib.dumps({}))
            env = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
            def configure():
                subprocess.run([sys.executable, str(root / 'tool/setup.py'), '--skip-checks'], env=env, check=True, capture_output=True)
            configure()
            first = {p.relative_to(root): p.read_bytes() for p in root.rglob('*') if p.is_file()}
            configure()
            second = {p.relative_to(root): p.read_bytes() for p in root.rglob('*') if p.is_file()}
            self.assertEqual(first, second)
            self.assertEqual((root / 'README.md').read_text(), files['README.md'])
            self.assertIn('android.permission.VIBRATE', (root / 'android/app/src/main/AndroidManifest.xml').read_text())
            self.assertIn('minSdk = 24', (root / 'android/app/build.gradle.kts').read_text())
            self.assertIn('8.12.1', (root / 'android/settings.gradle.kts').read_text())
            self.assertIn('gradle-8.13-all.zip', (root / 'android/gradle/wrapper/gradle-wrapper.properties').read_text())
            with (root / 'ios/Runner/Info.plist').open('rb') as file:
                self.assertEqual(plistlib.load(file)['CFBundleDisplayName'], 'Document Scanner')
            self.assertIn("platform :ios, '15.5'", (root / 'ios/Podfile').read_text())

if __name__ == '__main__':
    unittest.main()
