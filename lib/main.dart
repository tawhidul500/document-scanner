import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'data/document_store.dart';
import 'data/app_preferences.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    await AppPreferences.instance.load();
  } catch (_) {
    /* Keep defaults if preferences cannot be read. */
  }
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Document Scanner',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Inter',
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C59C1)),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: const Color(0xFF0F2A5C),
        displayColor: const Color(0xFF0F2A5C),
      ),
    ),
    home: const StartupScreen(),
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
  const StartupScreen({super.key, this.loader = loadStartupDocuments});
  final StartupLoader loader;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  DocumentStore? store;
  Object? error;
  double? progress;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      progress = null;
    });
    DocumentStore? next;
    try {
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
                const Text(
                  'Could not open your saved files. Your data has not been reset.',
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    if (store == null) return SplashScreen(progress: progress);
    return HomeScreen(store: store!);
  }
}
