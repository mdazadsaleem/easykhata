import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import 'auth_providers.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum AddCustomerStatus { idle, uploading, saving, success, error }

class AddCustomerState {
  const AddCustomerState({
    this.status = AddCustomerStatus.idle,
    this.uploadProgress = 0,
    this.errorMessage,
    this.createdCustomer,
  });

  final AddCustomerStatus status;
  final double uploadProgress;
  final String? errorMessage;
  final CustomerModel? createdCustomer;

  bool get isLoading =>
      status == AddCustomerStatus.uploading ||
      status == AddCustomerStatus.saving;
}

class AddCustomerInput {
  const AddCustomerInput({
    required this.name,
    required this.phone,
    required this.accountType,
    required this.address,
    required this.openingBalance,
    required this.balanceDirection,
    required this.notes,
    this.profileImage,
  });

  final String name;
  final String phone;
  final String accountType;
  final String address;
  final double openingBalance;
  final String balanceDirection;
  final String notes;
  final File? profileImage;
}

final addCustomerProvider =
    NotifierProvider<AddCustomerNotifier, AddCustomerState>(
      AddCustomerNotifier.new,
    );

class AddCustomerNotifier extends Notifier<AddCustomerState> {
  @override
  AddCustomerState build() => const AddCustomerState();

  Future<void> create(AddCustomerInput input) async {
    if (state.isLoading) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null) {
      state = const AddCustomerState(
        status: AddCustomerStatus.error,
        errorMessage: 'Please sign in again before adding a customer.',
      );
      return;
    }
    if (business == null || business.ownerId != user.uid) {
      state = const AddCustomerState(
        status: AddCustomerStatus.error,
        errorMessage: 'Your business could not be verified. Please try again.',
      );
      return;
    }
    final phone = normalizePakistanPhone(input.phone);
    if (phone == null) {
      state = const AddCustomerState(
        status: AddCustomerStatus.error,
        errorMessage: 'Enter a valid Pakistani mobile number.',
      );
      return;
    }

    try {
      final repository = ref.read(customerRepositoryProvider);
      final customerId = repository.customerIdFor(business.id, phone);
      if (await repository.phoneExists(
        ownerId: user.uid,
        businessId: business.id,
        normalizedPhone: phone,
      )) {
        throw const CustomerAlreadyExistsException();
      }
      var imageUrl = '';
      if (input.profileImage != null) {
        state = const AddCustomerState(status: AddCustomerStatus.uploading);
        imageUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${business.id}/customers/$customerId/profile.jpg',
              file: input.profileImage!,
              onProgress: (progress) {
                state = AddCustomerState(
                  status: AddCustomerStatus.uploading,
                  uploadProgress: progress,
                );
              },
            );
      }

      state = const AddCustomerState(status: AddCustomerStatus.saving);
      final opening = input.openingBalance;
      final direction = opening == 0 ? 'settled' : input.balanceDirection;
      final currentBalance = switch (direction) {
        'receivable' => opening,
        'payable' => -opening,
        _ => 0.0,
      };
      final customer = CustomerModel(
        id: customerId,
        ownerId: user.uid,
        businessId: business.id,
        name: input.name.trim(),
        phone: phone,
        address: input.address.trim(),
        accountType: input.accountType,
        openingBalance: opening,
        balanceType: direction,
        currentBalance: currentBalance,
        profileImage: imageUrl,
        notes: input.notes.trim(),
      );
      final created = await repository.createWithOpeningBalance(customer);
      state = AddCustomerState(
        status: AddCustomerStatus.success,
        uploadProgress: 1,
        createdCustomer: created,
      );
    } on CustomerAlreadyExistsException catch (error) {
      state = AddCustomerState(
        status: AddCustomerStatus.error,
        errorMessage: error.toString(),
      );
    } catch (_) {
      state = const AddCustomerState(
        status: AddCustomerStatus.error,
        errorMessage:
            'Could not save this customer. Check your connection and try again.',
      );
    }
  }

  void reset() => state = const AddCustomerState();
}
