import 'package:flutter/material.dart';
import '../../data/app_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/language_options.dart';
import '../../theme/app_theme.dart';

/// Selection is a local preview. Next commits the language and completion flag
/// together; StartupScreen then replaces this screen with Home.
class LanguageSetupScreen extends StatefulWidget {
  const LanguageSetupScreen({super.key, required this.preferences});
  final AppPreferences preferences;

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  String? selectedLanguage;
  bool saving = false;
  bool saveFailed = false;

  Future<void> next() async {
    final language = selectedLanguage;
    if (saving || language == null) return;
    setState(() {
      saving = true;
      saveFailed = false;
    });
    try {
      await widget.preferences.completeLanguageSetup(language);
    } catch (_) {
      if (mounted) setState(() => saveFailed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: Locale(selectedLanguage ?? widget.preferences.language),
    child: Builder(builder: buildScreen),
  );

  Widget buildScreen(BuildContext context) {
    final palette = AppPalette.of(context);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: palette.header,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: palette.header,
          foregroundColor: Colors.white,
          systemOverlayStyle: palette.systemBars,
          title: const AppText('Language',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: palette.background,
            child: SafeArea(
              top: false,
              bottom: false,
              child: ListView(
                key: const ValueKey('first-launch-languages'),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  Row(children: [
                    Image.asset(themedAsset(context, 'assets/theme/language.png'),
                        width: 44, height: 44, excludeFromSemantics: true),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('Choose App Language', style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700,
                            color: palette.text)),
                        const SizedBox(height: 6),
                        AppText('Select a language to continue.', style: TextStyle(
                            fontSize: 15, color: palette.secondary)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 24),
                  for (final language in appLanguageOptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        checked: selectedLanguage == language.$1,
                        inMutuallyExclusiveGroup: true,
                        enabled: !saving,
                        child: Material(
                          color: selectedLanguage == language.$1
                              ? palette.selected : palette.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(width: 1.5,
                                color: selectedLanguage == language.$1
                                    ? palette.primary : palette.outline),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: ValueKey('first-language-${language.$1}'),
                            minTileHeight: 72,
                            leading: Text(language.$2,
                                style: const TextStyle(fontSize: 30)),
                            title: Text(language.$3, style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: palette.text)),
                            subtitle: AppText(language.$4, style: TextStyle(
                                fontSize: 14, color: palette.secondary)),
                            trailing: Icon(selectedLanguage == language.$1
                                ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: selectedLanguage == language.$1
                                    ? palette.primary : palette.controlOutline),
                            onTap: saving ? null : () => setState(() {
                              selectedLanguage = language.$1;
                              saveFailed = false;
                            }),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: ColoredBox(
          color: palette.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (saveFailed) ...[
                  Semantics(liveRegion: true, child: AppText(
                    'Could not save language. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.danger, fontSize: 15))),
                  const SizedBox(height: 12),
                ],
                SizedBox(width: double.infinity, child: FilledButton(
                  key: const ValueKey('first-language-next'),
                  onPressed: selectedLanguage == null || saving ? null : next,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    disabledBackgroundColor: palette.selected,
                    disabledForegroundColor: palette.disabled,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: AppText('Next', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    if (saving)
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                          strokeWidth: 2, color: palette.primary))
                    else
                      const Icon(Icons.arrow_forward, size: 20),
                  ]),
                )),
                const SizedBox(height: 12),
                AppText('You can change this later in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.secondary, fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
