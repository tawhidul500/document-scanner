#!/usr/bin/env python3
"""Generate native Flutter runners and apply platform prerequisites.
Run from any folder: python3 tool/setup.py. Requires Flutter on PATH.
"""
from pathlib import Path
import argparse
import tempfile
import plistlib
import re
import shutil
import subprocess
import sys

def version(value):
    return tuple(int(x) for x in value.split('.'))

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--org', default='com.example', help='Reverse-domain organization for new runners')
parser.add_argument('--skip-checks', action='store_true', help='Configure runners without pub/analyze/test')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
flutter = shutil.which('flutter')
if not flutter:
    sys.exit('Install Flutter 3.44+ (recommended 3.47.7) and add flutter/bin to PATH.')
# Generate in isolation: never overwrite lib, tests, pubspec, README or existing runners.
missing = [platform for platform in ('android', 'ios') if not (root / platform).exists()]
if missing:
    with tempfile.TemporaryDirectory(prefix='scanner_runner_') as temporary:
        subprocess.run([flutter, 'create', '--no-pub', '--platforms=' + ','.join(missing),
                        '--project-name', 'pdf_scanner', '--org', args.org, temporary], check=True)
        scaffold = Path(temporary)
        for platform in missing:
            shutil.copytree(scaffold / platform, root / platform)
        if not (root / '.metadata').exists() and (scaffold / '.metadata').exists():
            shutil.copy2(scaffold / '.metadata', root / '.metadata')

manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text()
if 'android.permission.CAMERA' not in text:
    text = re.sub(r'(<manifest\b[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.CAMERA"/>\n    <uses-feature android:name="android.hardware.camera" android:required="false"/>', text, count=1)
if 'android.permission.VIBRATE' not in text:
    text = re.sub(r'(<manifest\b[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.VIBRATE"/>', text, count=1)
text = text.replace('android:label="pdf_scanner"', 'android:label="Document Scanner"')
manifest.write_text(text)

build = root / 'android/app/build.gradle.kts'
if not build.exists():
    build = root / 'android/app/build.gradle'
text = build.read_text()
text = re.sub(r'minSdk\s*=\s*flutter.minSdkVersion', 'minSdk = 24', text)
text = re.sub(r'minSdkVersion\s+flutter.minSdkVersion', 'minSdkVersion 24', text)
build.write_text(text)
# Raise older generated Android toolchain versions to share_plus prerequisites.
for settings in [root/'android/settings.gradle.kts', root/'android/settings.gradle']:
    if not settings.exists(): continue
    text = settings.read_text()
    for plugin, minimum in [('com.android.application','8.12.1'), ('org.jetbrains.kotlin.android','2.2.0')]:
        pattern = r'((?:id\("'+re.escape(plugin)+r'"\)|id\s+[\"\x27]'+re.escape(plugin)+r'[\"\x27])\s+version\s+[\"\x27])([0-9.]+)'
        text = re.sub(pattern, lambda m: m[1] + (minimum if version(m[2]) < version(minimum) else m[2]), text)
    settings.write_text(text)
wrapper = root / 'android/gradle/wrapper/gradle-wrapper.properties'
text = wrapper.read_text()
text = re.sub(r'gradle-([0-9.]+)-(all|bin)\.zip', lambda m: 'gradle-' + ('8.13' if version(m[1]) < version('8.13') else m[1]) + '-' + m[2] + '.zip', text)
wrapper.write_text(text)

info = root / 'ios/Runner/Info.plist'
with info.open('rb') as f: data = plistlib.load(f)
data['NSCameraUsageDescription'] = 'Scan documents, ID cards, QR codes and barcodes.'
data['CFBundleAllowMixedLocalizations'] = True
data['CFBundleDisplayName'] = 'Document Scanner'
data['NSPhotoLibraryUsageDescription'] = 'Choose document images to scan.'
with info.open('wb') as f: plistlib.dump(data, f)
project = root / 'ios/Runner.xcodeproj/project.pbxproj'
text = project.read_text()
text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);', lambda m: 'IPHONEOS_DEPLOYMENT_TARGET = ' + ('15.5' if version(m[1]) < version('15.5') else m[1]) + ';', text)
project.write_text(text)
framework_info = root / 'ios/Flutter/AppFrameworkInfo.plist'
if framework_info.exists():
    with framework_info.open('rb') as f: framework = plistlib.load(f)
    framework['MinimumOSVersion'] = '15.5'
    with framework_info.open('wb') as f: plistlib.dump(framework, f)
podfile = root / 'ios/Podfile'
if not podfile.exists():
    # Native OCR and printing require CocoaPods. Use Flutter's own template.
    sdk = Path(flutter).resolve().parents[1]
    template = sdk / 'packages/flutter_tools/templates/cocoapods/Podfile-ios'
    if not template.exists():
        sys.exit('Flutter CocoaPods template not found. Install full Flutter SDK.')
    shutil.copy2(template, podfile)
if podfile.exists():
    text = podfile.read_text()
    text = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.5'", text)
    if 'use_frameworks!' not in text: text = text.replace("target 'Runner' do", "target 'Runner' do\n  use_frameworks!")
    marker = 'flutter_additional_ios_build_settings(target)'
    if marker in text and "EXCLUDED_ARCHS[sdk=*]" not in text:
        text = text.replace(marker, marker + "\n    target.build_configurations.each do |config|\n      config.build_settings['EXCLUDED_ARCHS[sdk=*]'] = 'armv7'\n      if Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '0') < Gem::Version.new('15.5')\n        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'\n      end\n    end", 1)
    podfile.write_text(text)
if not args.skip_checks:
    subprocess.run([flutter, 'pub', 'get'], cwd=root, check=True)
    subprocess.run([flutter, 'pub', 'run', 'flutter_native_splash:create'], cwd=root, check=True)
    subprocess.run([flutter, 'analyze'], cwd=root, check=True)
    subprocess.run([flutter, 'test'], cwd=root, check=True)
print('Native runners configured.' if args.skip_checks else 'Setup and Flutter checks passed.')
