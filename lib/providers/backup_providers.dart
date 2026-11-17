import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_metadata_model.dart';
import '../models/backup_model.dart';
import '../repositories/backup_repository.dart';
import 'business_providers.dart';
import 'cashbook_providers.dart';
import 'customer_providers.dart';
import 'dashboard_providers.dart';
import 'app_providers.dart';
import 'language_providers.dart';
import 'notification_providers.dart';
import 'reminder_providers.dart';
import 'report_providers.dart';
import 'settings_preferences_provider.dart';
import 'settings_providers.dart';
import 'transaction_providers.dart';

enum BackupOperation {
  idle,
  backingUp,
  downloading,
  restoring,
  exporting,
  deleting,
}

class BackupState {
  const BackupState({
    this.backups = const [],
    this.operation = BackupOperation.idle,
    this.progress = 0,
    this.automaticEnabled = false,
    this.frequency = 'Weekly',
    this.selectedMetadata,
    this.selectedBackup,
    this.restoreResult,
    this.message,
    this.error,
  });

  final List<BackupMetadataModel> backups;
  final BackupOperation operation;
  final double progress;
  final bool automaticEnabled;
  final String frequency;
  final BackupMetadataModel? selectedMetadata;
  final BackupModel? selectedBackup;
  final RestoreResult? restoreResult;
  final String? message;
  final String? error;

  bool get isBusy => operation != BackupOperation.idle;
  BackupMetadataModel? get latest => backups.isEmpty ? null : backups.first;

  BackupState copyWith({
    List<BackupMetadataModel>? backups,
    BackupOperation? operation,
    double? progress,
    bool? automaticEnabled,
    String? frequency,
    BackupMetadataModel? selectedMetadata,
    BackupModel? selectedBackup,
    RestoreResult? restoreResult,
    String? message,
    String? error,
    bool clearSelection = false,
    bool clearResult = false,
  }) => BackupState(
    backups: backups ?? this.backups,
    operation: operation ?? this.operation,
    progress: progress ?? this.progress,
    automaticEnabled: automaticEnabled ?? this.automaticEnabled,
    frequency: frequency ?? this.frequency,
    selectedMetadata: clearSelection
        ? null
        : selectedMetadata ?? this.selectedMetadata,
    selectedBackup: clearSelection
        ? null
        : selectedBackup ?? this.selectedBackup,
    restoreResult: clearResult ? null : restoreResult ?? this.restoreResult,
    message: message,
    error: error,
  );
}

final backupRepositoryProvider = Provider(
  (ref) => BackupRepository(),
);

final backupProvider = AsyncNotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);

class BackupNotifier extends AsyncNotifier<BackupState> {
  static const _automaticKey = 'automatic_backup_enabled';
  static const _frequencyKey = 'automatic_backup_frequency';

  @override
  Future<BackupState> build() async {
    final scope = await _scope();
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_automaticKey) ?? false;
    final frequency = preferences.getString(_frequencyKey) ?? 'Weekly';
    var backups = await ref
        .watch(backupRepositoryProvider)
        .watchBackups(ownerId: scope.$1, businessId: scope.$2)
        .first;
    if (enabled && _isDue(backups.firstOrNull?.createdAt, frequency)) {
      await ref
          .read(backupRepositoryProvider)
          .createBackup(
            ownerId: scope.$1,
            businessId: scope.$2,
            onProgress: (_) {},
          );
      backups = await ref
          .read(backupRepositoryProvider)
          .watchBackups(ownerId: scope.$1, businessId: scope.$2)
          .first;
    }
    return BackupState(
      backups: backups,
      automaticEnabled: enabled,
      frequency: frequency,
    );
  }

  Future<bool> backupNow() async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    final scope = await _scope();
    state = AsyncData(
      current.copyWith(
        operation: BackupOperation.backingUp,
        progress: 0,
        clearResult: true,
      ),
    );
    try {
      await ref
          .read(backupRepositoryProvider)
          .createBackup(
            ownerId: scope.$1,
            businessId: scope.$2,
            onProgress: (progress) => _setProgress(progress),
          );
      await _reload(
        message: 'Backup completed successfully.',
        automaticEnabled: current.automaticEnabled,
        frequency: current.frequency,
      );
      return true;
    } catch (error) {
      _setError(_message(error));
      return false;
    }
  }

  Future<bool> setAutomatic(bool enabled) async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    try {
      final scope = await _scope();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_automaticKey, enabled);
      await ref
          .read(backupRepositoryProvider)
          .saveAutomaticPreference(
            ownerId: scope.$1,
            enabled: enabled,
            frequency: current.frequency,
          );
      state = AsyncData(
        current.copyWith(
          automaticEnabled: enabled,
          message: 'Automatic backup preference saved.',
        ),
      );
      return true;
    } catch (error) {
      _setError(_message(error));
      return false;
    }
  }

  Future<bool> setFrequency(String frequency) async {
    const allowed = {'Daily', 'Weekly', 'Monthly'};
    final current = state.value;
    if (current == null || current.isBusy || !allowed.contains(frequency)) {
      return false;
    }
    try {
      final scope = await _scope();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_frequencyKey, frequency);
      await ref
          .read(backupRepositoryProvider)
          .saveAutomaticPreference(
            ownerId: scope.$1,
            enabled: current.automaticEnabled,
            frequency: frequency,
          );
      state = AsyncData(
        current.copyWith(
          frequency: frequency,
          message: 'Backup frequency saved.',
        ),
      );
      return true;
    } catch (error) {
      _setError(_message(error));
      return false;
    }
  }

  Future<BackupModel?> prepareRestore(BackupMetadataModel metadata) async {
    final current = state.value;
    if (current == null || current.isBusy) return null;
    final scope = await _scope();
    state = AsyncData(
      current.copyWith(
        operation: BackupOperation.downloading,
        progress: 0,
        clearResult: true,
      ),
    );
    try {
      final backup = await ref
          .read(backupRepositoryProvider)
          .readAndValidate(
            metadata: metadata,
            ownerId: scope.$1,
            businessId: scope.$2,
            onProgress: _setProgress,
          );
      state = AsyncData(
        current.copyWith(
          operation: BackupOperation.idle,
          progress: 1,
          selectedMetadata: metadata,
          selectedBackup: backup,
        ),
      );
      return backup;
    } catch (error) {
      _setError(_message(error));
      return null;
    }
  }

  Future<RestoreResult?> restoreSelected() async {
    final current = state.value;
    final backup = current?.selectedBackup;
    if (current == null || current.isBusy || backup == null) return null;
    final scope = await _scope();
    state = AsyncData(
      current.copyWith(
        operation: BackupOperation.restoring,
        progress: 0,
        clearResult: true,
      ),
    );
    try {
      final result = await ref
          .read(backupRepositoryProvider)
          .restore(
            backup: backup,
            ownerId: scope.$1,
            businessId: scope.$2,
            onProgress: _setProgress,
          );
      await _restoreLocalPreferences(backup.user);
      _refreshDataProviders();
      final restoredAutomatic =
          backup.user['automaticBackupEnabled'] as bool? ??
          current.automaticEnabled;
      final restoredFrequency =
          backup.user['automaticBackupFrequency'] as String? ??
          current.frequency;
      await _reload(
        message:
            'Restore finished: ${result.restored} restored, '
            '${result.failed} failed.',
        automaticEnabled: restoredAutomatic,
        frequency: restoredFrequency,
        restoreResult: result,
      );
      return result;
    } catch (error) {
      _setError(_message(error));
      return null;
    }
  }

  Future<bool> exportBackup(BackupMetadataModel metadata) async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    final scope = await _scope();
    state = AsyncData(
      current.copyWith(operation: BackupOperation.exporting, progress: 0),
    );
    try {
      final file = await ref
          .read(backupRepositoryProvider)
          .downloadBackup(
            metadata,
            ownerId: scope.$1,
            businessId: scope.$2,
            onProgress: _setProgress,
          );
      await _share(file);
      state = AsyncData(
        current.copyWith(
          operation: BackupOperation.idle,
          progress: 1,
          message: 'Backup exported successfully.',
        ),
      );
      return true;
    } catch (error) {
      _setError(_message(error));
      return false;
    }
  }

  Future<bool> deleteBackup(BackupMetadataModel metadata) async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    final scope = await _scope();
    state = AsyncData(current.copyWith(operation: BackupOperation.deleting));
    try {
      await ref
          .read(backupRepositoryProvider)
          .deleteBackup(
            metadata: metadata,
            ownerId: scope.$1,
            businessId: scope.$2,
          );
      await _reload(
        message: 'Backup deleted.',
        automaticEnabled: current.automaticEnabled,
        frequency: current.frequency,
      );
      return true;
    } catch (error) {
      _setError(_message(error));
      return false;
    }
  }

  Future<(String, String)> _scope() async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw StateError('You are not authenticated.');
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null || business.ownerId != user.uid) {
      throw StateError('Selected business is unavailable.');
    }
    return (user.uid, business.id);
  }

  Future<void> _reload({
    required bool automaticEnabled,
    required String frequency,
    String? message,
    RestoreResult? restoreResult,
  }) async {
    final scope = await _scope();
    final backups = await ref
        .read(backupRepositoryProvider)
        .watchBackups(ownerId: scope.$1, businessId: scope.$2)
        .first;
    state = AsyncData(
      BackupState(
        backups: backups,
        automaticEnabled: automaticEnabled,
        frequency: frequency,
        progress: 1,
        message: message,
        restoreResult: restoreResult,
      ),
    );
  }

  void _setProgress(double progress) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(progress: progress.clamp(0, 1)));
    }
  }

  void _setError(String error) {
    final current = state.value ?? const BackupState();
    state = AsyncData(
      current.copyWith(operation: BackupOperation.idle, error: error),
    );
  }

  bool _isDue(DateTime? latest, String frequency) {
    if (latest == null) return true;
    final interval = switch (frequency) {
      'Daily' => const Duration(days: 1),
      'Monthly' => const Duration(days: 30),
      _ => const Duration(days: 7),
    };
    return DateTime.now().difference(latest) >= interval;
  }

  Future<void> _share(File file) => SharePlus.instance.share(
    ShareParams(
      text: 'Smart Khata local backup',
      files: [XFile(file.path, mimeType: 'application/json')],
    ),
  );

  void _refreshDataProviders() {
    ref.invalidate(currentBusinessProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(businessTransactionsProvider);
    ref.invalidate(cashbookEntriesProvider);
    ref.invalidate(remindersProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(reportProvider);
    ref.invalidate(languageProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(settingsPreferencesProvider);
  }

  Future<void> _restoreLocalPreferences(Map<String, dynamic> user) async {
    final preferences = await SharedPreferences.getInstance();
    final automatic = user['automaticBackupEnabled'];
    final frequency = user['automaticBackupFrequency'];
    final notifications = user['notificationsEnabled'];
    final dateFormat = user['dateFormat'];
    final theme = user['themeMode'];
    final language = user['language'];
    if (automatic is bool) await preferences.setBool(_automaticKey, automatic);
    if (frequency is String) {
      await preferences.setString(_frequencyKey, frequency);
    }
    if (notifications is bool) {
      await preferences.setBool('notifications_enabled', notifications);
    }
    if (dateFormat is String) {
      await preferences.setString('date_format', dateFormat);
    }
    if (theme is String) await preferences.setString('theme', theme);
    if (language is String) await preferences.setString('language', language);
  }

  String _message(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('another account') ||
        text.contains('ownership') ||
        text.contains('access was denied')) {
      return 'This backup does not belong to the selected business.';
    }
    if (text.contains('schema') || text.contains('version')) {
      return 'This backup version is not supported.';
    }
    if (text.contains('network') || text.contains('unavailable')) {
      return 'Could not load data. Please try again.';
    }
    if (text.contains('permission')) {
      return 'Backup access was denied.';
    }
    return 'Backup operation failed. Please try again.';
  }
}
