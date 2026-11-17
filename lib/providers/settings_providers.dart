import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/theme_persistence_service.dart';

final themePersistenceServiceProvider = Provider<ThemePersistenceService>((_) {
  throw StateError(
    'themePersistenceServiceProvider must be overridden during startup.',
  );
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ref.watch(themePersistenceServiceProvider).loadThemeMode();

  Future<void> set(ThemeMode value) async {
    if (state == value) return;
    final previous = state;
    state = value;
    try {
      await ref.read(themePersistenceServiceProvider).saveThemeMode(value);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
