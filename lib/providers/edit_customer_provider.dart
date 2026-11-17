import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import 'auth_providers.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final customerByIdProvider = StreamProvider.family<CustomerModel?, String>((
  ref,
  customerId,
) async* {
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
      .watch(customerRepositoryProvider)
      .watchById(
        customerId: customerId,
        ownerId: user.uid,
        businessId: business.id,
      );
});

enum EditCustomerStatus {
  idle,
  uploading,
  saving,
  deleting,
  success,
  deleted,
  error,
}

class EditCustomerState {
  const EditCustomerState({
    this.status = EditCustomerStatus.idle,
    this.progress = 0,
    this.customer,
    this.errorMessage,
    this.archived = false,
  });
  final EditCustomerStatus status;
  final double progress;
  final CustomerModel? customer;
  final String? errorMessage;
  final bool archived;
  bool get isLoading =>
      status == EditCustomerStatus.uploading ||
      status == EditCustomerStatus.saving ||
      status == EditCustomerStatus.deleting;
}

final editCustomerProvider =
    NotifierProvider<EditCustomerNotifier, EditCustomerState>(
      EditCustomerNotifier.new,
    );

class EditCustomerNotifier extends Notifier<EditCustomerState> {
  @override
  EditCustomerState build() => const EditCustomerState();

  Future<void> update({
    required CustomerModel original,
    required String name,
    required String phoneInput,
    required String address,
    required String accountType,
    required String notes,
    File? newImage,
  }) async {
    if (state.isLoading) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null ||
        business == null ||
        original.ownerId != user.uid ||
        original.businessId != business.id) {
      state = const EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: 'You do not have permission to update this customer.',
      );
      return;
    }
    final phone = normalizePakistanPhone(phoneInput);
    if (phone == null) {
      state = const EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: 'Enter a valid Pakistani mobile number.',
      );
      return;
    }
    try {
      final repository = ref.read(customerRepositoryProvider);
      if (await repository.phoneExistsForAnotherCustomer(
        ownerId: user.uid,
        businessId: business.id,
        normalizedPhone: phone,
        excludedCustomerId: original.id,
      )) {
        throw const CustomerAlreadyExistsException();
      }

      var imageUrl = original.profileImage;
      if (newImage != null) {
        state = const EditCustomerState(status: EditCustomerStatus.uploading);
        final version = DateTime.now().microsecondsSinceEpoch;
        imageUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/customers/${original.id}/profile_$version.jpg',
              file: newImage,
              onProgress: (progress) => state = EditCustomerState(
                status: EditCustomerStatus.uploading,
                progress: progress,
              ),
            );
      }
      state = const EditCustomerState(status: EditCustomerStatus.saving);
      final updated = original.copyWith(
        name: name.trim(),
        phone: phone,
        address: address.trim(),
        accountType: accountType,
        notes: notes.trim(),
        profileImage: imageUrl,
      );
      await repository.updateEditable(updated);
      if (newImage != null &&
          original.profileImage.isNotEmpty &&
          original.profileImage != imageUrl) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(original.profileImage);
        } catch (_) {
          // The customer update is already safe; stale-image cleanup can retry later.
        }
      }
      state = EditCustomerState(
        status: EditCustomerStatus.success,
        progress: 1,
        customer: updated,
      );
    } on CustomerAlreadyExistsException catch (error) {
      state = EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: error.toString(),
      );
    } on CustomerPermissionException catch (error) {
      state = EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: error.toString(),
      );
    } catch (_) {
      state = const EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: 'Could not update this customer. Please try again.',
      );
    }
  }

  Future<void> delete(CustomerModel customer) async {
    if (state.isLoading) return;
    state = const EditCustomerState(status: EditCustomerStatus.deleting);
    try {
      final permanentlyDeleted = await ref
          .read(customerRepositoryProvider)
          .deleteSafely(customer);
      if (permanentlyDeleted && customer.profileImage.isNotEmpty) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(customer.profileImage);
        } catch (_) {
          // The record deletion succeeded; stale file cleanup is non-blocking.
        }
      }
      state = EditCustomerState(
        status: EditCustomerStatus.deleted,
        customer: customer,
        archived: !permanentlyDeleted,
      );
    } catch (_) {
      state = const EditCustomerState(
        status: EditCustomerStatus.error,
        errorMessage: 'Could not delete this customer. Please try again.',
      );
    }
  }

  void reset() => state = const EditCustomerState();
}
