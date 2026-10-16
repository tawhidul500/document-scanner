import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/scan_feedback.dart';
import 'package:path_provider/path_provider.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences({this.file, ScanFeedback? feedback})
      : _feedback = feedback ?? ScanFeedback.instance;
  final ScanFeedback _feedback;
  static final instance = AppPreferences();
  File? file;
  Future<void> _pending = Future.value();
  String language = 'en';
  bool languageSetupComplete = false;
  ThemeMode themeMode = ThemeMode.system;
  bool vibration = true;
  bool beep = true;
  static const languages = [
    'en',
    'bn',
    'hi',
    'ar',
    'es',
    'fr',
    'ru',
    'id',
    'pt',
  ];

  Future<File> destination() async => file ??= File(
    '${(await getApplicationSupportDirectory()).path}/app_preferences.json',
  );
  Future<void> load() async {
    final target = await destination();
    if (!await target.exists()) return;
    final data =
        jsonDecode(await target.readAsString()) as Map<String, dynamic>;
    language = languages.contains(data['language'])
        ? data['language'] as String
        : 'en';
    // Existing installs with a valid saved language have already made a choice.
    // New installs explicitly persist false until the first-launch Next succeeds.
    languageSetupComplete = languages.contains(data['language']) &&
        (data.containsKey('languageSetupComplete')
            ? data['languageSetupComplete'] == true
            : true);
    themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == data['themeMode'],
      orElse: () => ThemeMode.system,
    );
    vibration = data['vibration'] is bool ? data['vibration'] as bool : true;
    beep = data['beep'] is bool ? data['beep'] as bool : true;
    notifyListeners();
  }

  Future<void> completeLanguageSetup(String language) =>
      update(language: language, languageSetupComplete: true);

  Future<void> update({String? language, bool? vibration, bool? beep,
      ThemeMode? themeMode, bool? languageSetupComplete}) {
    final next = _pending.then(
      (_) => _write(language: language, vibration: vibration, beep: beep,
          themeMode: themeMode, languageSetupComplete: languageSetupComplete),
    );
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write({String? language, bool? vibration, bool? beep,
      ThemeMode? themeMode, bool? languageSetupComplete}) async {
    if (language != null && !languages.contains(language))
      throw ArgumentError('Unsupported language');
    final nextLanguage = language ?? this.language;
    final nextLanguageSetupComplete = languageSetupComplete ?? this.languageSetupComplete;
    final nextVibration = vibration ?? this.vibration;
    final nextBeep = beep ?? this.beep;
    final nextThemeMode = themeMode ?? this.themeMode;
    final target = await destination();
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'language': nextLanguage,
        'languageSetupComplete': nextLanguageSetupComplete,
        'vibration': nextVibration,
        'beep': nextBeep,
        'themeMode': nextThemeMode.name,
      }),
      flush: true,
    );
    await temporary.rename(target.path);
    this.language = nextLanguage;
    this.languageSetupComplete = nextLanguageSetupComplete;
    this.vibration = nextVibration;
    this.beep = nextBeep;
    this.themeMode = nextThemeMode;
    notifyListeners();
  }

  Future<void> prepareScanFeedback() async {
    if (beep) await _feedback.prepare();
  }

  Future<void> scanFeedback() =>
      _feedback.play(beep: beep, vibration: vibration);
}
