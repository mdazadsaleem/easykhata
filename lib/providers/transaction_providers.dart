import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final businessTransactionsProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return Stream.value([]);
  return ref
      .watch(transactionRepositoryProvider)
      .watchBusiness(user.uid, business.id);
});

final customerTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, customerId) {
      final user = ref.watch(currentUserProvider);
      final business = ref.watch(currentBusinessProvider).value;
      if (user == null || business == null || customerId.isEmpty) {
        return Stream.value([]);
      }
      return ref
          .watch(transactionRepositoryProvider)
          .watchCustomer(user.uid, business.id, customerId);
    });

enum LedgerMutationStatus { idle, saving, deleting, success, error }

class LedgerMutationState {
  const LedgerMutationState({
    this.status = LedgerMutationStatus.idle,
    this.errorMessage,
  });
  final LedgerMutationStatus status;
  final String? errorMessage;
  bool get isLoading =>
      status == LedgerMutationStatus.saving ||
      status == LedgerMutationStatus.deleting;
}

final ledgerMutationProvider =
    NotifierProvider<LedgerMutationNotifier, LedgerMutationState>(
      LedgerMutationNotifier.new,
    );

class LedgerMutationNotifier extends Notifier<LedgerMutationState> {
  @override
  LedgerMutationState build() => const LedgerMutationState();

  Future<bool> delete(TransactionModel transaction) async {
    if (state.isLoading) return false;
    state = const LedgerMutationState(status: LedgerMutationStatus.deleting);
    try {
      await ref.read(transactionRepositoryProvider).delete(transaction);
      if (transaction.receiptUrl.isNotEmpty) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(transaction.receiptUrl);
        } catch (_) {
          // Balance deletion succeeded; receipt cleanup is non-blocking.
        }
      }
      state = const LedgerMutationState(status: LedgerMutationStatus.success);
      return true;
    } catch (_) {
      state = const LedgerMutationState(
        status: LedgerMutationStatus.error,
        errorMessage: 'Could not delete this transaction. Please try again.',
      );
      return false;
    }
  }

  Future<bool> update(
    TransactionModel transaction,
    double amount,
    String description,
  ) async {
    if (state.isLoading) return false;
    state = const LedgerMutationState(status: LedgerMutationStatus.saving);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateEditable(
            original: transaction,
            amount: amount,
            description: description,
          );
      state = const LedgerMutationState(status: LedgerMutationStatus.success);
      return true;
    } catch (_) {
      state = const LedgerMutationState(
        status: LedgerMutationStatus.error,
        errorMessage: 'Could not update this transaction. Please try again.',
      );
      return false;
    }
  }
}
