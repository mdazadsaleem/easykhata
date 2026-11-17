import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  SharedPreferencesService(this._preferences);
  final SharedPreferences _preferences;

  static const _onboardingKey = 'onboarding';
  static const _languageKey = 'language';
  static const _languageSelectedKey = 'language_selected';
  static const _notificationsKey = 'notifications_enabled';
  static const _dateFormatKey = 'date_format';

  bool get isOnboardingComplete =>
      _preferences.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _preferences.setBool(_onboardingKey, value);

  String get selectedLanguage => _preferences.getString(_languageKey) ?? 'en';

  bool get isLanguageSelected =>
      _preferences.getBool(_languageSelectedKey) ?? false;

  Future<void> saveLanguage(String languageCode) async {
    await _preferences.setString(_languageKey, languageCode);
    await _preferences.setBool(_languageSelectedKey, true);
  }

  bool get notificationsEnabled =>
      _preferences.getBool(_notificationsKey) ?? true;

  Future<void> saveNotificationsEnabled(bool value) =>
      _preferences.setBool(_notificationsKey, value);

  String get dateFormat =>
      _preferences.getString(_dateFormatKey) ?? 'dd MMM yyyy';

  Future<void> saveDateFormat(String value) =>
      _preferences.setString(_dateFormatKey, value);
}
