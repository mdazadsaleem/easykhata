import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePersistenceService {
  ThemePersistenceService(this._preferences);

  final SharedPreferences _preferences;
  static const _themeModeKey = 'theme';

  ThemeMode loadThemeMode() {
    final saved = _preferences.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _preferences.setString(_themeModeKey, mode.name);
}
