import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/local_notification_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/business_repository.dart';
import '../repositories/cashbook_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/customer_statement_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/transaction_repository.dart';

final authRepositoryProvider = Provider((ref) => const AuthRepository());
final localUserProvider = Provider((ref) => const LocalUser());
final currentUserProvider = Provider<LocalUser?>((ref) => const LocalUser());

final businessRepositoryProvider = Provider((ref) => BusinessRepository());
final customerRepositoryProvider = Provider((ref) => CustomerRepository());
final cashbookRepositoryProvider = Provider((ref) => CashbookRepository());
final transactionRepositoryProvider = Provider((ref) => TransactionRepository());
final reportRepositoryProvider = Provider((ref) => ReportRepository());
final customerStatementRepositoryProvider =
    Provider((ref) => CustomerStatementRepository());
final reminderRepositoryProvider = Provider((ref) => ReminderRepository());
final localNotificationServiceProvider = Provider(
  (_) => LocalNotificationService(),
);
final storageRepositoryProvider = Provider((ref) => StorageRepository());
final authStateProvider = StreamProvider(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);
