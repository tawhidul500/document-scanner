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
    # --- R8 fix: ignore missing ML Kit non-Latin recognizer classes ---
    _app = root / 'android' / 'app'
    _app.mkdir(parents=True, exist_ok=True)
    _rules_file = _app / 'proguard-rules.pro'
    _existing_rules = _rules_file.read_text(encoding='utf-8') if _rules_file.exists() else ''
    _mlkit_rules = (
        '-dontwarn com.google.mlkit.vision.text.chinese.**\n'
        '-dontwarn com.google.mlkit.vision.text.devanagari.**\n'
        '-dontwarn com.google.mlkit.vision.text.japanese.**\n'
        '-dontwarn com.google.mlkit.vision.text.korean.**\n'
    )
    _missing_rules = [rule for rule in _mlkit_rules.splitlines()
                      if rule not in _existing_rules.splitlines()]
    if _missing_rules:
        _rules_file.write_text(
            _existing_rules.rstrip() + '\n' + '\n'.join(_missing_rules) + '\n',
            encoding='utf-8',
        )
    for _name in ('build.gradle.kts', 'build.gradle'):
        _gradle = _app / _name
        if not _gradle.exists():
            continue
        _src = _gradle.read_text(encoding='utf-8')
        if 'proguard-rules.pro' not in _src:
            if _name.endswith('.kts'):
                _src += (
                    '\nandroid {\n'
                    '    buildTypes {\n'
                    '        getByName("release") {\n'
                    '            proguardFiles("proguard-rules.pro")\n'
                    '        }\n'
                    '    }\n'
                    '}\n'
                )
            else:
                _src += (
                    "\nandroid {\n"
                    "    buildTypes {\n"
                    "        release {\n"
                    "            proguardFiles 'proguard-rules.pro'\n"
                    "        }\n"
                    "    }\n"
                    "}\n"
                )
            _gradle.write_text(_src, encoding='utf-8')
        break
    # --- end R8 fix ---
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
