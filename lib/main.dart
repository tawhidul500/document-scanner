import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'theme/app_theme.dart';
import 'data/document_store.dart';
import 'data/app_preferences.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/language_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key, this.preferences, this.home});
  final AppPreferences? preferences;
  final Widget? home;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: preferences ?? AppPreferences.instance,
    builder: (context, _) => MaterialApp(
      title: 'Document Scanner',
      onGenerateTitle: (context) => context.tr('Document Scanner'),
      locale: Locale((preferences ?? AppPreferences.instance).language),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher
          .accessibilityFeatures.disableAnimations
          ? Duration.zero : const Duration(milliseconds: 250),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: (context, child) {
        final palette = AppPalette.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: palette.systemBars.copyWith(
            statusBarIconBrightness: palette.dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: palette.dark ? Brightness.dark : Brightness.light),
          child: child ?? const SizedBox.shrink(),
        );
      },
      themeMode: (preferences ?? AppPreferences.instance).themeMode,
      home: home ?? StartupScreen(preferences: preferences ?? AppPreferences.instance),
    ),
  );
}

typedef StartupLoader =
    Future<DocumentStore> Function(ValueChanged<double> onProgress);

Future<DocumentStore> loadStartupDocuments(
  ValueChanged<double> onProgress,
) async {
  final root = await getApplicationDocumentsDirectory();
  final store = DocumentStore(Directory('${root.path}/scans'));
  try {
    await store.load(onProgress: onProgress);
    return store;
  } catch (_) {
    store.dispose();
    rethrow;
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, this.loader = loadStartupDocuments, this.preferences});
  final StartupLoader loader;
  final AppPreferences? preferences;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  DocumentStore? store;
  Object? error;
  double? progress;
  bool animationComplete = false;
  AppPreferences get preferences => widget.preferences ?? AppPreferences.instance;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      progress = null;
      animationComplete = false;
    });
    DocumentStore? next;
    try {
      // Keep the opening animation visible during preference and file loading.
      try {
        await preferences.load();
      } catch (_) {
        /* Keep defaults if preferences cannot be read. */
      }
      if (!mounted) return;
      next = await widget.loader((value) {
        if (mounted) setState(() => progress = value);
      });
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() => store = next);
    } catch (e) {
      next?.dispose();
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null)
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppText(
                  'Could not open your saved files. Your data has not been reset.',
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const AppText('Try again')),
              ],
            ),
          ),
        ),
      );
    if (store == null || !animationComplete) {
      return SplashScreen(
        progress: progress,
        onAnimationComplete: () {
          if (mounted) setState(() => animationComplete = true);
        },
      );
    }
    return AnimatedBuilder(
      animation: preferences,
      builder: (_, child) => preferences.languageSetupComplete
          ? HomeScreen(store: store!)
          : LanguageSetupScreen(preferences: preferences),
    );
  }
}
