import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/routes/app_routes.dart';
import '../core/database/hive_database.dart';
import '../core/services/shared_preferences_service.dart';
import '../repositories/auth_repository.dart';
import 'app_providers.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferencesService>((
  ref,
) async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesService(preferences);
});

final startupAuthenticationProvider = StreamProvider<LocalUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final businessCompletionProvider = FutureProvider.family<bool, String>((
  ref,
  ownerId,
) async {
  final business = await ref
      .watch(businessRepositoryProvider)
      .watchForOwner(ownerId)
      .first;
  return business != null;
});

enum StartupDestination {
  onboarding(AppRoutes.onboarding),
  login(AppRoutes.businessSetup), // Skip login entirely
  businessSetup(AppRoutes.businessSetup),
  main(AppRoutes.main);

  const StartupDestination(this.route);
  final String route;
}

final startupProvider =
    AsyncNotifierProvider<StartupNotifier, StartupDestination>(
      StartupNotifier.new,
    );

class StartupNotifier extends AsyncNotifier<StartupDestination> {
  @override
  Future<StartupDestination> build() async {
    await HiveDatabase.instance.init();

    final preferences = await ref.watch(sharedPreferencesProvider.future);
    if (!preferences.isOnboardingComplete) {
      return StartupDestination.onboarding;
    }

    final user = await ref
        .read(authRepositoryProvider)
        .authStateChanges
        .first;

    final ownerId = user?.uid ?? HiveDatabase.defaultUserId;
    final business = await ref
        .read(businessRepositoryProvider)
        .watchForOwner(ownerId)
        .first;

    return business != null
        ? StartupDestination.main
        : StartupDestination.businessSetup;
  }

  void retry() {
    ref.invalidate(sharedPreferencesProvider);
    ref.invalidate(startupAuthenticationProvider);
    ref.invalidateSelf();
  }
}
