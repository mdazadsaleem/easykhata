import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cashbook_entry_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final cashbookEntryByIdProvider =
    StreamProvider.family<CashbookEntryModel?, String>((ref, entryId) async* {
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
          .watch(cashbookRepositoryProvider)
          .watchById(
            entryId: entryId,
            ownerId: user.uid,
            businessId: business.id,
          );
    });

enum EditCashEntryStatus {
  idle,
  uploading,
  saving,
  deleting,
  success,
  deleted,
  error,
}

class EditCashEntryState {
  const EditCashEntryState({
    this.status = EditCashEntryStatus.idle,
    this.progress = 0,
    this.entry,
    this.errorMessage,
  });
  final EditCashEntryStatus status;
  final double progress;
  final CashbookEntryModel? entry;
  final String? errorMessage;
  bool get isLoading =>
      status == EditCashEntryStatus.uploading ||
      status == EditCashEntryStatus.saving ||
      status == EditCashEntryStatus.deleting;
}

final editCashEntryProvider =
    NotifierProvider<EditCashEntryNotifier, EditCashEntryState>(
      EditCashEntryNotifier.new,
    );

class EditCashEntryNotifier extends Notifier<EditCashEntryState> {
  @override
  EditCashEntryState build() => const EditCashEntryState();

  Future<void> update({
    required CashbookEntryModel original,
    required String type,
    required double amount,
    required String category,
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
      state = const EditCashEntryState(
        status: EditCashEntryStatus.error,
        errorMessage: 'You do not have permission to edit this cash entry.',
      );
      return;
    }
    if (!amount.isFinite || amount <= 0 || category.trim().isEmpty) {
      state = const EditCashEntryState(
        status: EditCashEntryStatus.error,
        errorMessage: 'Enter a positive amount and select a category.',
      );
      return;
    }

    var receiptUrl = original.receiptUrl;
    var uploaded = false;
    try {
      if (newReceipt != null) {
        state = const EditCashEntryState(status: EditCashEntryStatus.uploading);
        final version = DateTime.now().microsecondsSinceEpoch;
        receiptUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/cashbook_receipts/${original.id}_$version.jpg',
              file: newReceipt,
              onProgress: (progress) => state = EditCashEntryState(
                status: EditCashEntryStatus.uploading,
                progress: progress,
              ),
            );
        uploaded = true;
      }
      state = const EditCashEntryState(status: EditCashEntryStatus.saving);
      final edited = CashbookEntryModel(
        id: original.id,
        ownerId: original.ownerId,
        businessId: original.businessId,
        type: type,
        amount: amount,
        category: category,
        description: description.trim(),
        paymentMethod: paymentMethod,
        receiptUrl: receiptUrl,
        entryDate: date,
        createdAt: original.createdAt,
      );
      await ref.read(cashbookRepositoryProvider).update(edited);
      if (uploaded &&
          original.receiptUrl.isNotEmpty &&
          original.receiptUrl != receiptUrl) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(original.receiptUrl);
        } catch (_) {}
      }
      state = EditCashEntryState(
        status: EditCashEntryStatus.success,
        progress: 1,
        entry: edited,
      );
    } catch (error) {
      if (uploaded && receiptUrl.isNotEmpty) {
        try {
          await ref.read(storageRepositoryProvider).deleteByUrl(receiptUrl);
        } catch (_) {}
      }
      state = EditCashEntryState(
        status: EditCashEntryStatus.error,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> delete(CashbookEntryModel entry) async {
    if (state.isLoading) return;
    state = const EditCashEntryState(status: EditCashEntryStatus.deleting);
    try {
      await ref.read(cashbookRepositoryProvider).delete(entry);
      if (entry.receiptUrl.isNotEmpty) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(entry.receiptUrl);
        } catch (_) {}
      }
      state = EditCashEntryState(
        status: EditCashEntryStatus.deleted,
        entry: entry,
      );
    } catch (error) {
      state = EditCashEntryState(
        status: EditCashEntryStatus.error,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  void reset() => state = const EditCashEntryState();
}
