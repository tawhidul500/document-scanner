import '../../data/app_preferences.dart';
import '../../l10n/app_localizations.dart';

// Compatibility helper. UI widgets use AppText/context.tr to observe locale changes.
String settingsText(String key) =>
    AppStrings.translate(key, AppPreferences.instance.language);
