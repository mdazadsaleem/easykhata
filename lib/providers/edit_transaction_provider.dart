import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final transactionByIdProvider =
    StreamProvider.family<TransactionModel?, String>((ref, id) async* {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        yield null;
        return;
      }
      final business = await ref.watch(currentBusinessProvider.future);
      if (business == null) {
        yield null;
        return;
      }
      yield* ref
          .watch(transactionRepositoryProvider)
          .watchById(
            transactionId: id,
            ownerId: user.uid,
            businessId: business.id,
          );
    });

enum EditTransactionStatus {
  idle,
  uploading,
  saving,
  deleting,
  success,
  deleted,
  error,
}

class EditTransactionState {
  const EditTransactionState({
    this.status = EditTransactionStatus.idle,
    this.progress = 0,
    this.transaction,
    this.errorMessage,
  });
  final EditTransactionStatus status;
  final double progress;
  final TransactionModel? transaction;
  final String? errorMessage;
  bool get isLoading =>
      status == EditTransactionStatus.uploading ||
      status == EditTransactionStatus.saving ||
      status == EditTransactionStatus.deleting;
}

final editTransactionProvider =
    NotifierProvider<EditTransactionNotifier, EditTransactionState>(
      EditTransactionNotifier.new,
    );

class EditTransactionNotifier extends Notifier<EditTransactionState> {
  @override
  EditTransactionState build() => const EditTransactionState();

  Future<void> update({
    required TransactionModel original,
    required String type,
    required double amount,
    required DateTime date,
    required String description,
    required String paymentMethod,
    File? newReceipt,
  }) async {
    if (state.isLoading) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null ||
        business == null ||
        original.ownerId != user.uid ||
        original.businessId != business.id) {
      state = const EditTransactionState(
        status: EditTransactionStatus.error,
        errorMessage: 'You do not have permission to edit this transaction.',
      );
      return;
    }
    if (!amount.isFinite || amount <= 0) {
      state = const EditTransactionState(
        status: EditTransactionStatus.error,
        errorMessage: 'Enter an amount greater than zero.',
      );
      return;
    }

    var receiptUrl = original.receiptUrl;
    var uploadedNewReceipt = false;
    try {
      if (newReceipt != null) {
        state = const EditTransactionState(
          status: EditTransactionStatus.uploading,
        );
        final version = DateTime.now().microsecondsSinceEpoch;
        receiptUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/receipts/${original.id}_$version.jpg',
              file: newReceipt,
              onProgress: (progress) => state = EditTransactionState(
                status: EditTransactionStatus.uploading,
                progress: progress,
              ),
            );
        uploadedNewReceipt = true;
      }
      state = const EditTransactionState(status: EditTransactionStatus.saving);
      final updated = await ref
          .read(transactionRepositoryProvider)
          .updateAtomic(
            original.copyWith(
              transactionType: type,
              amount: amount,
              transactionDate: date,
              description: description,
              paymentMethod: paymentMethod,
              receiptUrl: receiptUrl,
            ),
          );
      if (uploadedNewReceipt &&
          original.receiptUrl.isNotEmpty &&
          original.receiptUrl != receiptUrl) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(original.receiptUrl);
        } catch (_) {}
      }
      state = EditTransactionState(
        status: EditTransactionStatus.success,
        progress: 1,
        transaction: updated,
      );
    } catch (error) {
      if (uploadedNewReceipt && receiptUrl.isNotEmpty) {
        try {
          await ref.read(storageRepositoryProvider).deleteByUrl(receiptUrl);
        } catch (_) {}
      }
      state = EditTransactionState(
        status: EditTransactionStatus.error,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> delete(TransactionModel transaction) async {
    if (state.isLoading) return;
    state = const EditTransactionState(status: EditTransactionStatus.deleting);
    try {
      await ref.read(transactionRepositoryProvider).delete(transaction);
      if (transaction.receiptUrl.isNotEmpty) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(transaction.receiptUrl);
        } catch (_) {}
      }
      state = EditTransactionState(
        status: EditTransactionStatus.deleted,
        transaction: transaction,
      );
    } catch (error) {
      state = EditTransactionState(
        status: EditTransactionStatus.error,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  void reset() => state = const EditTransactionState();
}
