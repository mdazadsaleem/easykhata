import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/user_preferences_repository.dart';
import 'app_providers.dart';
import 'startup_providers.dart';

final userPreferencesRepositoryProvider = Provider(
  (ref) => UserPreferencesRepository(),
);

final languageProvider = AsyncNotifierProvider<LanguageNotifier, String>(
  LanguageNotifier.new,
);

class LanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return preferences.selectedLanguage == 'ur' ? 'ur' : 'en';
  }

  void select(String languageCode) {
    if (state.isLoading) return;
    state = AsyncData(languageCode == 'ur' ? 'ur' : 'en');
  }

  Future<bool> save() async {
    if (state.isLoading) return false;
    final selected = state.value ?? 'en';
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      await preferences.saveLanguage(selected);

      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref
            .read(userPreferencesRepositoryProvider)
            .updateLanguage(userId: user.uid, languageCode: selected);
      }
      return selected;
    });
    return !state.hasError;
  }
}
