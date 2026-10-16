import '../../theme/app_motion.dart';
import '../../l10n/language_options.dart';
import 'package:pdf_scanner/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../widgets/settings_icon.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_preferences.dart';
import '../../widgets/reference_navigation.dart';

const _storeUrl = String.fromEnvironment('APP_STORE_URL');
const _privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
const _termsUrl = String.fromEnvironment('TERMS_URL');
const _moreAppsUrl = String.fromEnvironment('MORE_APPS_URL');


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onScan});
  final VoidCallback? onScan;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool saving = false;
  Future<void> update({bool? vibration, bool? beep}) async {
    setState(() => saving = true);
    try {
      await AppPreferences.instance.update(vibration: vibration, beep: beep);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not save settings. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> link(String title, String value) async {
    final uri = Uri.tryParse(value);
    if (value.isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: AppText(context.tr(title)),
          content: const AppText(
            'This link is not available in this version yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const AppText('OK'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw StateError('Unavailable');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not open this link. Please try again.'),
          ),
        );
    }
  }

  Future<void> share() async {
    final box = context.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${context.tr('Document Scanner — Scan, save and share your documents.')}${_storeUrl.isEmpty ? '' : '\n$_storeUrl'}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Sharing is unavailable. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppPreferences.instance,
    builder: (_, child) {
      final prefs = AppPreferences.instance;
      final language = appLanguageOptions.firstWhere((l) => l.$1 == prefs.language).$4;
      return _SettingsShell(
        brand: true, onScan: widget.onScan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 25, 15, 28),
          children: [
            _section('App Settings'),
            _card([
              _row('language', 'Language', language,
                value: language,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LanguageScreen(onScan: widget.onScan)))),
              _row('theme', 'Theme', 'Appearance of the app',
                value: themeModeLabel(prefs.themeMode),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ThemeScreen(onScan: widget.onScan)))),
              _row('vibration', 'Vibration', 'Vibrate during scanning',
                trailing: _ReferenceSwitch(value: prefs.vibration,
                  label: context.tr('Vibration'),
                  onChanged: saving ? null : (v) => update(vibration: v))),
              _row('beep', 'Beep', 'Sound during scanning',
                trailing: _ReferenceSwitch(value: prefs.beep,
                  label: context.tr('Beep'),
                  onChanged: saving ? null : (v) => update(beep: v))),
            ]),
            const SizedBox(height: 12),
            _section('Support'),
            _card([
              _row('share', 'Share With Friend', 'Recommend this app', onTap: share),
              _row('rate', 'Rate Us', 'Leave a Google Play review',
                onTap: () => link('Rate Us', _storeUrl)),
              _row('privacy', 'Privacy Policy', 'How your data is handled',
                onTap: () => link('Privacy Policy', _privacyUrl)),
              _row('terms', 'Terms & Conditions', 'Terms of use',
                onTap: () => link('Terms & Conditions', _termsUrl)),
              _row('apps', 'More Apps', 'Explore other apps',
                onTap: () => link('More Apps', _moreAppsUrl)),
            ]),
            const SizedBox(height: 12),
            _section('About'),
            _card([
              _row('about', 'About App', 'App information and version',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AboutAppScreen(onScan: widget.onScan)))),
            ]),
          ],
        ),
      );
    },
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppText(context.tr(title), style: TextStyle(
      fontSize: 15, height: 1.35, fontWeight: FontWeight.w700,
      color: AppPalette.of(context).text)),
  );

  Widget _card(List<Widget> rows) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: AppPalette.of(context).dark ? .12 : .04),
        blurRadius: 8, offset: const Offset(0, 2),
      )],
    ),
    child: Material(
    color: AppPalette.of(context).surface,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Padding(
            padding: const EdgeInsetsDirectional.only(start: 62, end: 16),
            child: Divider(height: 1, thickness: 1,
              color: AppPalette.of(context).outline)),
          rows[i],
        ],
      ]),
    ),
    ),
  );

  Widget _row(String icon, String title, String subtitle, {
    String? value, Widget? trailing, VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          SettingsIcon(icon),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
              AppText(context.tr(title), style: TextStyle(
                color: AppPalette.of(context).text, fontSize: 14,
                height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              AppText(context.tr(subtitle), style: TextStyle(
                color: AppPalette.of(context).secondary, fontSize: 13, height: 1.35)),
            ])),
          if (value != null) ...[
            const SizedBox(width: 8),
            Flexible(fit: FlexFit.tight,
              child: AppText(context.tr(value), textAlign: TextAlign.end,
              style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 14))),
          ],
          const SizedBox(width: 10),
          trailing ?? Image.asset(themedAsset(context, 'assets/theme/chevron.png'), width: 9, height: 14, matchTextDirection: true,
            color: AppPalette.of(context).secondary, excludeFromSemantics: true),
        ]),
      ),
    ),
  );
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System Default',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key, this.preferences, this.onScan});
  final VoidCallback? onScan;
  final AppPreferences? preferences;
  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  bool saving = false;
  AppPreferences get preferences => widget.preferences ?? AppPreferences.instance;

  Future<void> select(ThemeMode mode) async {
    if (saving || preferences.themeMode == mode) return;
    setState(() => saving = true);
    try {
      await preferences.update(themeMode: mode);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: AppText('Could not save theme. Please try again.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: preferences,
    builder: (context, _) => _SettingsShell(
      title: context.tr('Theme'), onScan: widget.onScan,
      child: ListView(padding: const EdgeInsets.fromLTRB(10, 30, 19, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 25),
            decoration: BoxDecoration(
              color: AppPalette.of(context).surface,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppText(context.tr('Choose app appearance'), style: TextStyle(
                color: AppPalette.of(context).text, fontSize: 20,
                height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              AppText(context.tr('Select how Document Scanner looks on your device.'),
                style: TextStyle(color: AppPalette.of(context).secondary,
                  fontSize: 14, height: 1.35)),
              const SizedBox(height: 7.5),
              for (final mode in ThemeMode.values) ...[
                if (mode != ThemeMode.system) const SizedBox(height: 9),
                _option(mode),
              ],
            ]),
          ),
        ]),
    ),
  );

  Widget _option(ThemeMode mode) {
    final p = AppPalette.of(context);
    final selected = preferences.themeMode == mode;
    final description = switch (mode) {
      ThemeMode.system => 'Automatically switch between light and dark based on your device settings.',
      ThemeMode.light => 'Use the light appearance for a bright and clear experience.',
      ThemeMode.dark => 'Use the dark appearance for a comfortable experience in low light.',
    };
    return Semantics(
      checked: selected, inMutuallyExclusiveGroup: true,
      enabled: !saving, label: context.tr(themeModeLabel(mode)),
      child: Material(color: p.surface,
        animationDuration: AppMotion.duration(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? p.primary : p.outline,
            width: selected ? 1.409 : .939)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(key: ValueKey('theme-${mode.name}'),
          onTap: saving ? null : () => select(mode),
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 96),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
              child: Row(children: [
                SizedBox(width: 64, height: 64, child: Icon(
                  mode == ThemeMode.system ? Icons.brightness_auto_outlined
                    : mode == ThemeMode.light ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 40, color: p.primary)),
                const SizedBox(width: 16.5),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    AppText(context.tr(themeModeLabel(mode)), style: TextStyle(
                      fontSize: 14, height: 1.35, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 6),
                    AppText(context.tr(description), style: TextStyle(
                      fontSize: 12.5, height: 1.35, color: p.secondary)),
                  ])),
                const SizedBox(width: 8),
                Container(width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: selected ? p.primary : p.controlOutline,
                      width: 2.25)),
                  child: selected ? Center(child: Container(width: 10.33, height: 10.33,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.primary))) : null),
                const SizedBox(width: 7),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceSwitch extends StatelessWidget {
  const _ReferenceSwitch({required this.value, required this.label, this.onChanged});
  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr(label), toggled: value, enabled: onChanged != null,
    child: InkWell(onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(width: 44, height: 44, child: Center(
        child: AnimatedContainer(duration: AppMotion.duration(context),
          curve: AppMotion.curve,
          width: 41, height: 25.4, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            color: value ? AppPalette.of(context).primary : AppPalette.of(context).controlOutline),
          child: AnimatedAlign(duration: AppMotion.duration(context),
            curve: AppMotion.curve,
            alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            child: Container(width: 19.4, height: 19.4,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: value ? AppPalette.of(context).onPrimary : AppPalette.of(context).surface))),
        ),
      )),
    ),
  );
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.onScan});
  final VoidCallback? onScan;
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool saving = false;
  Future<void> select(String code) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await AppPreferences.instance.update(language: code);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not save language. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppPreferences.instance,
    builder: (_, child) => _SettingsShell(
      title: context.tr('Language'),
      onScan: widget.onScan,
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              color: AppPalette.of(context).selected,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.of(context).outline),
            ),
            child: Row(
              children: [
                const SettingsIcon('language'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        context.tr('Choose App Language'),
                        style: TextStyle(
                          color: AppPalette.of(context).text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      AppText(
                        context.tr('Change the language used in the app'),
                        style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final language in appLanguageOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: AppPreferences.instance.language == language.$1,
                button: true,
                child: Material(
                  color: AppPalette.of(context).surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppPreferences.instance.language == language.$1
                          ? AppPalette.of(context).primary
                          : AppPalette.of(context).outline,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    key: ValueKey('language-${language.$1}'),
                    dense: true,
                    leading: Text(
                      language.$2,
                      style: const TextStyle(fontSize: 32),
                    ),
                    title: Text(
                      language.$3,
                      style: TextStyle(
                        color: AppPalette.of(context).text,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: AppText(
                      language.$4,
                      style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 13),
                    ),
                    trailing: Icon(
                      AppPreferences.instance.language == language.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppPreferences.instance.language == language.$1
                          ? AppPalette.of(context).primary
                          : AppPalette.of(context).controlOutline,
                    ),
                    onTap: saving ? null : () => select(language.$1),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key, this.onScan});
  final VoidCallback? onScan;
  @override
  Widget build(BuildContext context) => _SettingsShell(
    onScan: onScan,
    title: context.tr('About App'),
    child: ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _panel(context,
          Row(
            children: [
              Image.asset('assets/home/brand.png', width: 60, height: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Document Scanner',
                      style: TextStyle(
                        color: AppPalette.of(context).text,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                    AppText(
                      'Scan • Save • Share',
                      style: TextStyle(color: AppPalette.of(context).secondary, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    _chip(context, 'Version 0.5.0'),
                  ],
                ),
              ),
            ],
          ),
        ),
        _heading(context, context.tr('About')),
        _panel(context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Transform your smartphone into a powerful portable scanner. Scan, organize, convert, and share your documents effortlessly from your mobile device.',
                style: TextStyle(color: AppPalette.of(context).text, height: 1.5, fontSize: 15),
              ),
              Divider(color: AppPalette.of(context).outline),
              AppText(
                'Works with',
                style: TextStyle(
                  color: AppPalette.of(context).secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final label in [
                    'Documents',
                    'Receipts',
                    'Notes',
                    'ID Cards',
                    'Certificates',
                    'Photos',
                  ])
                    _chip(context, label),
                ],
              ),
            ],
          ),
        ),
        _heading(context, 'Key Features'),
        for (final pair in [
          [
            (Icons.document_scanner_outlined, 'Scan docs\nto PDF', Colors.blue),
            (
              Icons.file_download_outlined,
              'Clear digital\ncopies',
              Colors.deepPurple,
            ),
          ],
          [
            (Icons.crop, 'Auto crop &\nenhance', Colors.green),
            (Icons.copy_outlined, 'Multi-page\nPDF files', Colors.orange),
          ],
          [
            (Icons.share_outlined, 'Save, manage\n& share', Colors.blue),
            (Icons.bolt, 'Fast & simple\nscanning', Colors.deepPurple),
          ],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < pair.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _panel(context,
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppPalette.of(context).selected,
                            child: Icon(
                              pair[i].$1,
                              color: AppPalette.of(context).primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: AppText(
                              pair[i].$2,
                              style: TextStyle(
                                color: AppPalette.of(context).text,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      padding: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppPalette.of(context).header,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Go paperless',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    AppText(
                      'Keep your important documents organized',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: AppText(
      text,
      style: TextStyle(
        color: AppPalette.of(context).text,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
    ),
  );
  Widget _panel(BuildContext context, Widget child, {double padding = 16}) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  Widget _chip(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppPalette.of(context).selected,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      text,
      style: TextStyle(
        color: AppPalette.of(context).primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({required this.child, this.title, this.brand = false, this.onScan, this.showNavigation = true});
  final Widget child;
  final String? title;
  final bool brand;
  final bool showNavigation;
  final VoidCallback? onScan;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: AppPalette.of(context).systemBars,
    child: Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: AppPalette.of(context).surface,
        appBar: AppBar(
          backgroundColor: AppPalette.of(context).header,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: AppPalette.of(context).systemBars,
          automaticallyImplyLeading: false,
          toolbarHeight: brand ? 84 : 64,
          titleSpacing: brand ? 15 : 9,
          leadingWidth: brand ? null : 56,
          leading: brand ? null : IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
          title: brand
              ? Row(
                  children: [
                    Semantics(button: true, label: context.tr('Back to Home'), child: GestureDetector(onTap: () => Navigator.maybePop(context), child: Image.asset('assets/home/brand.png', width: 39))),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Document Scanner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppText(
                            'Scan • Save • Share',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : AppText(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

        ),
        bottomNavigationBar: !showNavigation ? null : ReferenceHomeNavigation(
          settingsSelected: true,
          homeSelected: false,
          onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
          onScan: onScan == null ? null : () => scanFromNavigation(context, onScan),
          onSettings: () {
            if (!brand) Navigator.of(context).pop();
          },
        ),
        body: ColoredBox(color: AppPalette.of(context).header, child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: ColoredBox(
            color: AppPalette.of(context).dark
                ? AppPalette.of(context).background : const Color(0xFFF4F7FC),
            child: SizedBox.expand(child: child),
          ),
        )),
      ),
    ),
  );
}
