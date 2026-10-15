import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/app_preferences.dart';
import 'settings_strings.dart';

const _blue = Color(0xFF205BC3);
const _ink = Color(0xFF102B61);
const _pale = Color(0xFFF4F7FD);
const _muted = Color(0xFF7789A6);
const _storeUrl = String.fromEnvironment('APP_STORE_URL');
const _privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
const _termsUrl = String.fromEnvironment('TERMS_URL');
const _moreAppsUrl = String.fromEnvironment('MORE_APPS_URL');

const _languages = <(String, String, String, String)>[
  ('en', '🇬🇧', 'English', 'English'),
  ('bn', '🇧🇩', 'Bangladesh', 'Bengali'),
  ('hi', '🇮🇳', 'India', 'Hindi'),
  ('ar', '🇸🇦', 'Saudi Arabia', 'Arabic'),
  ('es', '🇪🇸', 'Español', 'Spanish'),
  ('fr', '🇫🇷', 'Français', 'French'),
  ('ru', '🇷🇺', 'Русский', 'Russian'),
  ('id', '🇮🇩', 'Bahasa Indonesia', 'Indonesian'),
  ('pt', '🇵🇹', 'Português', 'Portuguese'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
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
            content: Text('Could not save settings. Please try again.'),
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
          title: Text(settingsText(title)),
          content: const Text(
            'This link is not available in this version yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
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
            content: Text('Could not open this link. Please try again.'),
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
              'Document Scanner — Scan, save and share your documents.${_storeUrl.isEmpty ? '' : '\n$_storeUrl'}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing is unavailable. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppPreferences.instance,
    builder: (_, child) {
      final prefs = AppPreferences.instance;
      final language = _languages.firstWhere((l) => l.$1 == prefs.language).$4;
      return _SettingsShell(
        brand: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 22, 15, 28),
          children: [
            _section('App Settings'),
            _card([
              _row(
                Icons.language,
                const Color(0xFF1875EA),
                'Language',
                language,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      language,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: _muted, size: 20),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                ),
              ),
              _row(
                Icons.vibration,
                const Color(0xFF914CFF),
                'Vibration',
                'Vibrate during scanning',
                trailing: Switch.adaptive(
                  value: prefs.vibration,
                  activeTrackColor: _blue,
                  onChanged: saving ? null : (v) => update(vibration: v),
                ),
              ),
              _row(
                Icons.volume_up_outlined,
                const Color(0xFF16BE71),
                'Beep',
                'Sound during scanning',
                trailing: Switch.adaptive(
                  value: prefs.beep,
                  activeTrackColor: _blue,
                  onChanged: saving ? null : (v) => update(beep: v),
                ),
              ),
            ]),
            _section('Support'),
            _card([
              _row(
                Icons.share_outlined,
                const Color(0xFF1875EA),
                'Share With Friend',
                'Recommend this app',
                onTap: share,
              ),
              _row(
                Icons.star_border,
                const Color(0xFFFF930F),
                'Rate Us',
                'Leave a Google Play review',
                onTap: () => link('Rate Us', _storeUrl),
              ),
              _row(
                Icons.verified_user_outlined,
                const Color(0xFF16BE71),
                'Privacy Policy',
                'How your data is handled',
                onTap: () => link('Privacy Policy', _privacyUrl),
              ),
              _row(
                Icons.description_outlined,
                const Color(0xFF914CFF),
                'Terms & Conditions',
                'Terms of use',
                onTap: () => link('Terms & Conditions', _termsUrl),
              ),
              _row(
                Icons.grid_view_rounded,
                const Color(0xFF1875EA),
                'More Apps',
                'Explore other apps',
                onTap: () => link('More Apps', _moreAppsUrl),
              ),
            ]),
            _section('About'),
            _card([
              _row(
                Icons.info_outline,
                _ink,
                'About App',
                'App information, version, license',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                ),
              ),
            ]),
          ],
        ),
      );
    },
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 8),
    child: Text(
      settingsText(title),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
    ),
  );
  Widget _card(List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFEDF0F7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 62, end: 16),
                child: Divider(height: 1, color: Color(0xFFE5EBF5)),
              ),
            rows[i],
          ],
        ],
      ),
    ),
  );
  Widget _row(
    IconData icon,
    Color color,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
  }) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
    leading: CircleAvatar(
      radius: 19,
      backgroundColor: color.withValues(alpha: .12),
      child: Icon(icon, color: color, size: 23),
    ),
    title: Text(
      settingsText(title),
      style: const TextStyle(
        color: _ink,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Text(
      settingsText(subtitle),
      style: const TextStyle(color: _muted, fontSize: 11),
    ),
    trailing:
        trailing ?? const Icon(Icons.chevron_right, color: _muted, size: 22),
    onTap: onTap,
  );
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
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
            content: Text('Could not save language. Please try again.'),
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
      title: settingsText('Language'),
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1E4FF)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF1875EA),
                  child: Icon(Icons.language, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settingsText('Choose App Language'),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        settingsText('Change the language used in the app'),
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final language in _languages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: AppPreferences.instance.language == language.$1,
                button: true,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppPreferences.instance.language == language.$1
                          ? const Color(0xFF155CFF)
                          : const Color(0xFFEDF0F7),
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
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      language.$4,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    trailing: Icon(
                      AppPreferences.instance.language == language.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: AppPreferences.instance.language == language.$1
                          ? const Color(0xFF155CFF)
                          : const Color(0xFFB5C5DF),
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
  const AboutAppScreen({super.key});
  @override
  Widget build(BuildContext context) => _SettingsShell(
    title: settingsText('About App'),
    child: ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _panel(
          Row(
            children: [
              Image.asset('assets/home/brand.png', width: 60, height: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Scanner',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const Text(
                      'Scan • Save • Share',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    _chip('Version 0.4.0'),
                  ],
                ),
              ),
            ],
          ),
        ),
        _heading(settingsText('About')),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transform your smartphone into a powerful portable scanner. Scan, organize, convert, and share your documents effortlessly from your mobile device.',
                style: TextStyle(color: _ink, height: 1.5, fontSize: 13),
              ),
              const Divider(color: Color(0xFFE5EBF5)),
              const Text(
                'Works with',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
                    _chip(label),
                ],
              ),
            ],
          ),
        ),
        _heading('Key Features'),
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
                    child: _panel(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: pair[i].$3.withValues(alpha: .12),
                            child: Icon(
                              pair[i].$1,
                              color: pair[i].$3,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              pair[i].$2,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
            color: _blue,
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
                    Text(
                      'Go paperless',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Keep your important documents organized',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Document Scanner',
            applicationVersion: '0.4.0',
          ),
          child: const Text('Open-source licenses'),
        ),
      ],
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    ),
  );
  Widget _panel(Widget child, {double padding = 16}) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE3EEFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _blue,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({required this.child, this.title, this.brand = false});
  final Widget child;
  final String? title;
  final bool brand;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Directionality(
      textDirection: AppPreferences.instance.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _blue,
        appBar: AppBar(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: !brand,
          title: brand
              ? Row(
                  children: [
                    Image.asset('assets/home/brand.png', width: 38),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document Scanner',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Scan • Save • Share',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          actions: brand
              ? [
                  IconButton(
                    tooltip: 'Back to Home',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ]
              : null,
        ),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: _pale,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    ),
  );
}
