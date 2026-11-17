import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/account_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/storage_repository.dart';
import 'local_notification_service.dart';

class AccountDeletionService {
  AccountDeletionService({
    required this.accountRepository,
    required this.authRepository,
    required this.storage,
    required this.secureStorage,
    required this.notifications,
  });

  final AccountRepository accountRepository;
  final AuthRepository authRepository;
  final StorageRepository storage;
  final FlutterSecureStorage secureStorage;
  final LocalNotificationService notifications;

  Future<void> logout() async {
    await authRepository.signOut();
    await clearSensitiveLocalState();
  }

  Future<DeletionSummary> deleteAccount({
    required void Function(double progress, String stage) onProgress,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('No active account was found.');
    final ownerId = user.uid;
    var deletedFiles = 0;
    var deletedDocuments = 0;
    var stage = 'Preparing account reset';

    try {
      onProgress(.02, stage);
      final backupPaths = await accountRepository.backupStoragePaths(ownerId);
      final references = await accountRepository.ownerDataReferences(ownerId);

      stage = 'Deleting local storage files';
      onProgress(.15, stage);
      for (final path in backupPaths) {
        await storage.deleteByUrl(path);
        deletedFiles++;
      }

      stage = 'Clearing local database records';
      onProgress(.45, stage);
      await accountRepository.deleteReferencesInBatches(
        references: references,
        onProgress: (deleted, total) {
          deletedDocuments = deleted;
        },
      );

      stage = 'Deleting user profile';
      onProgress(.80, stage);
      await accountRepository.deleteUserDocument(ownerId);
      deletedDocuments++;

      stage = 'Clearing local security data';
      onProgress(.95, stage);
      await clearSensitiveLocalState();
      onProgress(1, 'Account data reset successfully');

      return DeletionSummary(
        deletedDocuments: deletedDocuments,
        deletedFiles: deletedFiles,
      );
    } catch (error) {
      if (error is AccountDeletionException) rethrow;
      throw AccountDeletionException(
        stage: stage,
        deletedDocuments: deletedDocuments,
        deletedFiles: deletedFiles,
        cause: error,
      );
    }
  }

  Future<void> clearSensitiveLocalState() async {
    final preferences = await SharedPreferences.getInstance();
    final theme = preferences.getString('theme');
    final onboardingComplete = preferences.getBool('onboarding');
    final language = preferences.getString('language');
    final languageSelected = preferences.getBool('language_selected');
    await preferences.clear();
    if (theme != null) await preferences.setString('theme', theme);
    if (onboardingComplete != null) {
      await preferences.setBool('onboarding', onboardingComplete);
    }
    if (language != null) await preferences.setString('language', language);
    if (languageSelected != null) {
      await preferences.setBool('language_selected', languageSelected);
    }
    await secureStorage.deleteAll();
    await notifications.cancelAll();
  }
}

class DeletionSummary {
  const DeletionSummary({
    required this.deletedDocuments,
    required this.deletedFiles,
  });

  final int deletedDocuments;
  final int deletedFiles;
}

class AccountDeletionException implements Exception {
  const AccountDeletionException({
    required this.stage,
    required this.deletedDocuments,
    required this.deletedFiles,
    required this.cause,
  });

  final String stage;
  final int deletedDocuments;
  final int deletedFiles;
  final Object cause;

  @override
  String toString() =>
      'AccountDeletionException at stage "$stage": $cause '
      '(deleted $deletedDocuments documents and $deletedFiles files)';
}
