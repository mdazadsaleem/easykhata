import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/services/account_deletion_service.dart';
import '../repositories/account_repository.dart';
import 'app_lock_providers.dart';
import 'backup_providers.dart';
import 'business_providers.dart';
import 'business_setup_providers.dart';
import 'cashbook_providers.dart';
import 'customer_providers.dart';
import 'dashboard_providers.dart';
import 'app_providers.dart';
import 'language_providers.dart';
import 'notification_providers.dart';
import 'profile_providers.dart';
import 'reminder_providers.dart';
import 'report_providers.dart';
import 'settings_preferences_provider.dart';
import 'startup_providers.dart';
import 'support_providers.dart';
import 'transaction_providers.dart';

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(),
);

final accountDeletionServiceProvider = Provider(
  (ref) => AccountDeletionService(
    accountRepository: ref.watch(accountRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    storage: ref.watch(storageRepositoryProvider),
    secureStorage: const FlutterSecureStorage(),
    notifications: ref.watch(localNotificationServiceProvider),
  ),
);

enum AccountAction { idle, loggingOut, deleting }

class AccountActionState {
  const AccountActionState({
    this.action = AccountAction.idle,
    this.progress = 0,
    this.stage = '',
    this.error,
    this.requiresRecentLogin = false,
    this.partialDeletion = false,
  });

  final AccountAction action;
  final double progress;
  final String stage;
  final String? error;
  final bool requiresRecentLogin;
  final bool partialDeletion;

  bool get isBusy => action != AccountAction.idle;
}

final accountActionProvider =
    NotifierProvider<AccountActionNotifier, AccountActionState>(
      AccountActionNotifier.new,
    );

class AccountActionNotifier extends Notifier<AccountActionState> {
  @override
  AccountActionState build() => const AccountActionState();

  Future<bool> logout() async {
    if (state.isBusy) return false;
    state = const AccountActionState(
      action: AccountAction.loggingOut,
      stage: 'Resetting local data',
    );
    try {
      await ref.read(accountDeletionServiceProvider).logout();
      _invalidateSensitiveProviders();
      state = const AccountActionState();
      return true;
    } catch (error) {
      state = AccountActionState(error: _accountError(error));
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (state.isBusy) return false;
    state = const AccountActionState(
      action: AccountAction.deleting,
      stage: 'Resetting local app data',
    );
    try {
      await ref
          .read(accountDeletionServiceProvider)
          .deleteAccount(
            onProgress: (progress, stage) {
              state = AccountActionState(
                action: AccountAction.deleting,
                progress: progress,
                stage: stage,
              );
            },
          );
      _invalidateSensitiveProviders();
      state = const AccountActionState(progress: 1, stage: 'Data reset successfully');
      return true;
    } catch (error) {
      state = AccountActionState(error: _accountError(error));
      return false;
    }
  }

  void _invalidateSensitiveProviders() {
    ref.invalidate(authStateProvider);
    ref.invalidate(currentBusinessProvider);
    ref.invalidate(businessSetupProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(businessTransactionsProvider);
    ref.invalidate(cashbookEntriesProvider);
    ref.invalidate(remindersProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(reportProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(profileActionProvider);
    ref.invalidate(backupProvider);
    ref.invalidate(supportSubmissionProvider);
    ref.invalidate(settingsPreferencesProvider);
    ref.invalidate(languageProvider);
    ref.invalidate(appLockSettingsProvider);
    ref.invalidate(appUnlockProvider);
    ref.invalidate(sharedPreferencesProvider);
    ref.invalidate(startupAuthenticationProvider);
    ref.invalidate(businessCompletionProvider);
    ref.invalidate(startupProvider);
  }

  String _accountError(Object error) {
    return 'The operation failed. Please try again.';
  }
}
