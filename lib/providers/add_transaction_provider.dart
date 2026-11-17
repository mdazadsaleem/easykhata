import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_model.dart';
import '../models/transaction_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum AddTransactionStatus { idle, uploading, saving, success, error }

class AddTransactionState {
  const AddTransactionState({
    this.status = AddTransactionStatus.idle,
    this.uploadProgress = 0,
    this.transaction,
    this.errorMessage,
  });
  final AddTransactionStatus status;
  final double uploadProgress;
  final TransactionModel? transaction;
  final String? errorMessage;
  bool get isLoading =>
      status == AddTransactionStatus.uploading ||
      status == AddTransactionStatus.saving;
}

class AddTransactionInput {
  const AddTransactionInput({
    required this.customer,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    required this.paymentMethod,
    this.receipt,
    this.reminderDate,
  });
  final CustomerModel customer;
  final String type;
  final double amount;
  final DateTime date;
  final String description;
  final String paymentMethod;
  final File? receipt;
  final DateTime? reminderDate;
}

final addTransactionProvider =
    NotifierProvider<AddTransactionNotifier, AddTransactionState>(
      AddTransactionNotifier.new,
    );

class AddTransactionNotifier extends Notifier<AddTransactionState> {
  @override
  AddTransactionState build() => const AddTransactionState();

  Future<void> create(AddTransactionInput input) async {
    if (state.isLoading) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null ||
        business == null ||
        input.customer.ownerId != user.uid ||
        input.customer.businessId != business.id) {
      state = const AddTransactionState(
        status: AddTransactionStatus.error,
        errorMessage: 'Customer ownership could not be verified.',
      );
      return;
    }
    if (!input.amount.isFinite || input.amount <= 0) {
      state = const AddTransactionState(
        status: AddTransactionStatus.error,
        errorMessage: 'Enter an amount greater than zero.',
      );
      return;
    }

    var receiptUrl = '';
    try {
      if (input.receipt != null) {
        state = const AddTransactionState(
          status: AddTransactionStatus.uploading,
        );
        final receiptId = DateTime.now().microsecondsSinceEpoch;
        receiptUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/receipts/$receiptId.jpg',
              file: input.receipt!,
              onProgress: (progress) => state = AddTransactionState(
                status: AddTransactionStatus.uploading,
                uploadProgress: progress,
              ),
            );
      }
      state = const AddTransactionState(status: AddTransactionStatus.saving);
      final created = await ref
          .read(transactionRepositoryProvider)
          .createAtomic(
            value: TransactionModel(
              id: '',
              ownerId: user.uid,
              businessId: business.id,
              customerId: input.customer.id,
              transactionType: input.type,
              amount: input.amount,
              description: input.description.trim(),
              receiptUrl: receiptUrl,
              paymentMethod: input.paymentMethod,
              transactionDate: input.date,
            ),
            customerName: input.customer.name,
            reminderDate: input.reminderDate,
          );
      state = AddTransactionState(
        status: AddTransactionStatus.success,
        uploadProgress: 1,
        transaction: created,
      );
    } catch (_) {
      if (receiptUrl.isNotEmpty) {
        try {
          await ref.read(storageRepositoryProvider).deleteByUrl(receiptUrl);
        } catch (_) {}
      }
      state = const AddTransactionState(
        status: AddTransactionStatus.error,
        errorMessage: 'Could not save the transaction. Please try again.',
      );
    }
  }

  void reset() => state = const AddTransactionState();
}
