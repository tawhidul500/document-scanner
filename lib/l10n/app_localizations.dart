import 'package:flutter/material.dart';

import 'app_catalog.dart';

/// English source keys stay separate from operation IDs and user content.
/// Reading Localizations makes every dependent route update without losing state.
class AppStrings {
  static const languages = ['en', 'bn', 'hi', 'ar', 'es', 'fr', 'ru', 'id', 'pt'];
  static const supportedLocales = [
    Locale('en'), Locale('bn'), Locale('hi'), Locale('ar'), Locale('es'),
    Locale('fr'), Locale('ru'), Locale('id'), Locale('pt'),
  ];

  static String translate(String key, String language,
      [Map<String, Object> arguments = const {}]) {
    final index = languages.indexOf(language);
    final values = appCatalog[key];
    final pattern = index > 0 && values != null ? values[index - 1] : key;
    return pattern.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) =>
        arguments[match[1]]?.toString() ?? match[0]!);
  }
}

extension AppTranslations on BuildContext {
  String get appLanguage => Localizations.localeOf(this).languageCode;
  bool get englishLayout => appLanguage == 'en';
  String tr(String key, [Map<String, Object> arguments = const {}]) =>
      AppStrings.translate(key, appLanguage, arguments);
  String? trOrNull(String? key) => key == null ? null : tr(key);
}

/// Use Text/SelectableText directly for filenames and scanned/user-entered text.
class AppText extends StatelessWidget {
  const AppText(this.data, {super.key, this.arguments = const {}, this.style,
    this.textAlign, this.textDirection, this.maxLines, this.overflow,
    this.softWrap, this.strutStyle, this.textHeightBehavior, this.textWidthBasis,
    this.semanticsLabel, this.locale, this.textScaler, this.selectionColor});
  final String data;
  final Map<String, Object> arguments;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  final TextWidthBasis? textWidthBasis;
  final String? semanticsLabel;
  final Locale? locale;
  final TextScaler? textScaler;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(context.tr(data, arguments),
    style: style, textAlign: textAlign, textDirection: textDirection,
    maxLines: maxLines, overflow: overflow, softWrap: softWrap,
    strutStyle: strutStyle, textHeightBehavior: textHeightBehavior,
    textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
    semanticsLabel: context.trOrNull(semanticsLabel), locale: locale,
    textScaler: textScaler, selectionColor: selectionColor);
}
