import 'package:flutter/material.dart';
import 'app_motion.dart';
import 'package:flutter/services.dart';

/// Semantic UI colors. Paper, camera pixels and signature ink are not themed.
class AppPalette {
  const AppPalette(this.dark);
  final bool dark;
  static AppPalette of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.dark);

  Color get surface => dark ? const Color(0xFF18233B) : Colors.white;
  Color get background => dark ? const Color(0xFF0D1530) : const Color(0xFFF6F9FE);
  Color get workspace => dark ? const Color(0xFF10192B) : const Color(0xFFEBEBEB);
  Color get text => dark ? const Color(0xFFF3F6FF) : const Color(0xFF0F2A5C);
  Color get secondary => dark ? const Color(0xFFB8C4DB) : const Color(0xFF566781);
  Color get outline => dark ? const Color(0xFF3D4D69) : const Color(0xFFE3E9F3);
  Color get controlOutline => dark ? const Color(0xFF9BAAC5) : const Color(0xFF7A879F);
  Color get primary => dark ? const Color(0xFF99BDFF) : const Color(0xFF1457C6);
  Color get onPrimary => dark ? const Color(0xFF0B1D3A) : Colors.white;
  Color get header => dark ? const Color(0xFF152B52) : const Color(0xFF1C59C1);
  Color get selected => dark ? const Color(0xFF263B61) : const Color(0xFFE4EDFD);
  Color get closeSurface => dark ? const Color(0xFF263B61) : const Color(0xFFEDEDED);
  Color get disabled => dark ? const Color(0xFF7E8CA5) : const Color(0xFF758195);
  Color get danger => dark ? const Color(0xFFFFACAB) : const Color(0xFFB3261E);

  SystemUiOverlayStyle get systemBars => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}

String themedAsset(BuildContext context, String path) =>
    AppPalette.of(context).dark
        ? path.replaceFirst('.png', '_dark.png') : path;

class AppThemes {
  static final light = _build(false);
  static final dark = _build(true);

  // A plain ThemeData().textTheme has no font sizes yet, so fontSizeDelta
  // would assert. Merge the Material size geometry in first.
  static TextTheme _baseTextTheme(bool dark) {
    final typography = Typography.material2021(platform: TargetPlatform.android);
    return typography.englishLike.merge(
        dark ? typography.white : typography.black);
  }

  static ThemeData _build(bool dark) {
    final p = AppPalette(dark);
    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1C59C1), brightness: brightness,
    ).copyWith(
      primary: p.primary, onPrimary: p.onPrimary,
      primaryContainer: p.selected, onPrimaryContainer: p.text,
      secondary: p.primary, onSecondary: p.onPrimary,
      secondaryContainer: p.selected, onSecondaryContainer: p.text,
      surface: p.surface, onSurface: p.text,
      onSurfaceVariant: p.secondary, outline: p.controlOutline,
      outlineVariant: p.outline, error: p.danger,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface, surfaceContainer: p.surface,
      surfaceContainerHigh: p.selected, surfaceContainerHighest: p.selected,
    );
    return ThemeData(
      useMaterial3: true, brightness: brightness, fontFamily: 'Inter',
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        ...const PageTransitionsTheme().builders,
        TargetPlatform.android: AppPageTransitions(),
        TargetPlatform.windows: AppPageTransitions(),
        TargetPlatform.linux: AppPageTransitions(),
        TargetPlatform.fuchsia: AppPageTransitions(),
      }),
      colorScheme: scheme, scaffoldBackgroundColor: p.background,
      canvasColor: p.surface, cardColor: p.surface, dividerColor: p.outline,
      disabledColor: p.disabled,
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: p.primary, disabledForegroundColor: p.disabled)),
      textTheme: _baseTextTheme(dark).apply(
        fontFamily: 'Inter', bodyColor: p.text, displayColor: p.text,
        fontSizeDelta: 2),
      iconTheme: IconThemeData(color: p.text),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface, foregroundColor: p.text,
        surfaceTintColor: Colors.transparent, elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 22,
          fontWeight: FontWeight.w700, color: p.text),
        systemOverlayStyle: p.systemBars.copyWith(
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light)),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface, surfaceTintColor: Colors.transparent,
        modalBarrierColor: const Color(0x700C0C0C)),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface, surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: p.surface, hintStyle: TextStyle(color: p.secondary),
        labelStyle: TextStyle(color: p.secondary)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.onPrimary : p.secondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.primary : p.outline)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFE4EDFD) : const Color(0xFF18233B),
        contentTextStyle: TextStyle(color: dark
          ? const Color(0xFF0F2A5C) : Colors.white),
        actionTextColor: dark ? const Color(0xFF1457C6) : const Color(0xFF99BDFF)),
    );
  }
}
