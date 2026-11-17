import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cashbook_entry_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum AddCashEntryStatus { idle, uploading, saving, success, error }

class AddCashEntryState {
  const AddCashEntryState({
    this.status = AddCashEntryStatus.idle,
    this.progress = 0,
    this.entry,
    this.errorMessage,
  });
  final AddCashEntryStatus status;
  final double progress;
  final CashbookEntryModel? entry;
  final String? errorMessage;
  bool get isLoading =>
      status == AddCashEntryStatus.uploading ||
      status == AddCashEntryStatus.saving;
}

class AddCashEntryInput {
  const AddCashEntryInput({
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.description,
    required this.paymentMethod,
    this.receipt,
  });
  final String type;
  final double amount;
  final String category;
  final DateTime date;
  final String description;
  final String paymentMethod;
  final File? receipt;
}

final addCashEntryProvider =
    NotifierProvider<AddCashEntryNotifier, AddCashEntryState>(
      AddCashEntryNotifier.new,
    );

class AddCashEntryNotifier extends Notifier<AddCashEntryState> {
  @override
  AddCashEntryState build() => const AddCashEntryState();

  Future<void> create(AddCashEntryInput input) async {
    if (state.isLoading) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null || business.ownerId != user.uid) {
      state = const AddCashEntryState(
        status: AddCashEntryStatus.error,
        errorMessage: 'Business ownership could not be verified.',
      );
      return;
    }
    if (!input.amount.isFinite || input.amount <= 0) {
      state = const AddCashEntryState(
        status: AddCashEntryStatus.error,
        errorMessage: 'Enter an amount greater than zero.',
      );
      return;
    }
    if (input.category.trim().isEmpty) {
      state = const AddCashEntryState(
        status: AddCashEntryStatus.error,
        errorMessage: 'Select a category.',
      );
      return;
    }

    var receiptUrl = '';
    try {
      if (input.receipt != null) {
        state = const AddCashEntryState(status: AddCashEntryStatus.uploading);
        final receiptId = DateTime.now().microsecondsSinceEpoch;
        receiptUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/cashbook_receipts/$receiptId.jpg',
              file: input.receipt!,
              onProgress: (progress) => state = AddCashEntryState(
                status: AddCashEntryStatus.uploading,
                progress: progress,
              ),
            );
      }
      state = const AddCashEntryState(status: AddCashEntryStatus.saving);
      final created = await ref
          .read(cashbookRepositoryProvider)
          .create(
            CashbookEntryModel(
              id: '',
              ownerId: user.uid,
              businessId: business.id,
              type: input.type,
              amount: input.amount,
              category: input.category,
              description: input.description.trim(),
              paymentMethod: input.paymentMethod,
              receiptUrl: receiptUrl,
              entryDate: input.date,
            ),
          );
      state = AddCashEntryState(
        status: AddCashEntryStatus.success,
        progress: 1,
        entry: created,
      );
    } catch (_) {
      if (receiptUrl.isNotEmpty) {
        try {
          await ref.read(storageRepositoryProvider).deleteByUrl(receiptUrl);
        } catch (_) {}
      }
      state = const AddCashEntryState(
        status: AddCashEntryStatus.error,
        errorMessage: 'Could not save this cash entry. Please try again.',
      );
    }
  }

  void reset() => state = const AddCashEntryState();
}
