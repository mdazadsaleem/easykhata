import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup_providers.dart';

final onboardingProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return preferences.isOnboardingComplete;
  }

  Future<bool> complete() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      await preferences.setOnboardingComplete(true);
      return true;
    });
    if (state.value == true) {
      ref.invalidate(startupProvider);
    }
    return state.value == true;
  }
}
