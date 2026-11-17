import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'language_providers.dart';
import 'startup_providers.dart';

class SettingsPreferences {
  const SettingsPreferences({
    this.notificationsEnabled = true,
    this.dateFormat = 'dd MMM yyyy',
    this.isSaving = false,
    this.error,
  });

  final bool notificationsEnabled;
  final String dateFormat;
  final bool isSaving;
  final String? error;

  SettingsPreferences copyWith({
    bool? notificationsEnabled,
    String? dateFormat,
    bool? isSaving,
    String? error,
  }) => SettingsPreferences(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    dateFormat: dateFormat ?? this.dateFormat,
    isSaving: isSaving ?? this.isSaving,
    error: error,
  );
}

final settingsPreferencesProvider =
    AsyncNotifierProvider<SettingsPreferencesNotifier, SettingsPreferences>(
      SettingsPreferencesNotifier.new,
    );

class SettingsPreferencesNotifier extends AsyncNotifier<SettingsPreferences> {
  @override
  Future<SettingsPreferences> build() async {
    final local = await ref.watch(sharedPreferencesProvider.future);
    return SettingsPreferences(
      notificationsEnabled: local.notificationsEnabled,
      dateFormat: local.dateFormat,
    );
  }

  Future<bool> setNotifications(bool value) async {
    final current = state.value ?? const SettingsPreferences();
    state = AsyncData(
      current.copyWith(notificationsEnabled: value, isSaving: true),
    );
    try {
      final local = await ref.read(sharedPreferencesProvider.future);
      await local.saveNotificationsEnabled(value);
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref
            .read(userPreferencesRepositoryProvider)
            .updateSettings(userId: user.uid, notificationsEnabled: value);
      }
      state = AsyncData(
        current.copyWith(notificationsEnabled: value, isSaving: false),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          error: 'Could not save notification preference.',
        ),
      );
      return false;
    }
  }

  Future<bool> setDateFormat(String value) async {
    final current = state.value ?? const SettingsPreferences();
    state = AsyncData(current.copyWith(dateFormat: value, isSaving: true));
    try {
      final local = await ref.read(sharedPreferencesProvider.future);
      await local.saveDateFormat(value);
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref
            .read(userPreferencesRepositoryProvider)
            .updateSettings(userId: user.uid, dateFormat: value);
      }
      state = AsyncData(current.copyWith(dateFormat: value, isSaving: false));
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(isSaving: false, error: 'Could not save date format.'),
      );
      return false;
    }
  }
}
