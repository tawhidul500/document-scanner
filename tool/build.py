#!/usr/bin/env python3
"""Configure, verify and build. No binary is reported unless Flutter succeeds."""
import argparse
from pathlib import Path
import platform
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('target', choices=['check', 'apk', 'ios', 'ipa'])
parser.add_argument('--org', default='com.example')
parser.add_argument('--defines', type=Path, help='JSON file containing public URL Dart defines')
args = parser.parse_args()
flutter = shutil.which('flutter')
if not flutter:
    sys.exit('Flutter is missing. Install Flutter 3.47.7 and add flutter/bin to PATH.')
if args.target in ['ios', 'ipa'] and platform.system() != 'Darwin':
    sys.exit('iOS compilation requires macOS with Xcode. IPA additionally needs Apple signing configured.')

def run(*command):
    subprocess.run(command, cwd=root, check=True)

run(sys.executable, 'tool/setup.py', '--org', args.org, '--skip-checks')
run(flutter, 'pub', 'get')
run(flutter, 'pub', 'run', 'flutter_native_splash:create')
run(flutter, 'analyze')
run(flutter, 'test', '--reporter', 'expanded', '--timeout', '2m')
defines = []
if args.defines:
    defines = ['--dart-define-from-file=' + str(args.defines.resolve())]
if args.target == 'apk':
    run(flutter, 'build', 'apk', '--release', *defines)
    source = root / 'build/app/outputs/flutter-apk/app-release.apk'
    destination = root / 'dist/document-scanner-android-test.apk'
    destination.parent.mkdir(exist_ok=True)
    shutil.copy2(source, destination)
    print(f'APK: {destination}\nFresh runners use Flutter development signing. Configure production signing for store release.')
elif args.target == 'ios':
    run(flutter, 'build', 'ios', '--release', '--no-codesign', *defines)
    source = root / 'build/ios/iphoneos/Runner.app'
    if not source.is_dir():
        sys.exit('Flutter succeeded but Runner.app was not found.')
    (root / 'dist').mkdir(exist_ok=True)
    result = shutil.make_archive(str(root / 'dist/document-scanner-ios-unsigned'), 'zip', root_dir=source.parent, base_dir=source.name)
    print(f'Unsigned iOS build: {result}\nThis is NOT an installable IPA; configure signing in Xcode.')
elif args.target == 'ipa':
    run(flutter, 'build', 'ipa', '--release', *defines)
    print('Signed IPA output: build/ios/ipa/ (signing/export must be configured in Xcode).')
