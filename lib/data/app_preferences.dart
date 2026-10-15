import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences({this.file});
  static final instance = AppPreferences();
  File? file;
  Future<void> _pending = Future.value();
  String language = 'en';
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
    vibration = data['vibration'] is bool ? data['vibration'] as bool : true;
    beep = data['beep'] is bool ? data['beep'] as bool : true;
    notifyListeners();
  }

  Future<void> update({String? language, bool? vibration, bool? beep}) {
    final next = _pending.then(
      (_) => _write(language: language, vibration: vibration, beep: beep),
    );
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write({String? language, bool? vibration, bool? beep}) async {
    if (language != null && !languages.contains(language))
      throw ArgumentError('Unsupported language');
    final nextLanguage = language ?? this.language;
    final nextVibration = vibration ?? this.vibration;
    final nextBeep = beep ?? this.beep;
    final target = await destination();
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'language': nextLanguage,
        'vibration': nextVibration,
        'beep': nextBeep,
      }),
      flush: true,
    );
    await temporary.rename(target.path);
    this.language = nextLanguage;
    this.vibration = nextVibration;
    this.beep = nextBeep;
    notifyListeners();
  }

  Future<void> scanFeedback() async {
    if (vibration) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (beep) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }
}
