import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_model.dart';
import 'auth_providers.dart';
import 'app_providers.dart';

enum BusinessSetupStatus { idle, uploading, saving, success, error }

class BusinessSetupState {
  const BusinessSetupState({
    this.status = BusinessSetupStatus.idle,
    this.uploadProgress = 0,
    this.businessId,
    this.message,
  });

  final BusinessSetupStatus status;
  final double uploadProgress;
  final String? businessId;
  final String? message;

  bool get isLoading =>
      status == BusinessSetupStatus.uploading ||
      status == BusinessSetupStatus.saving;
}

class BusinessSetupInput {
  const BusinessSetupInput({
    required this.ownerName,
    required this.businessName,
    required this.businessType,
    required this.phone,
    required this.address,
    required this.city,
    this.currency = 'PKR',
    this.logo,
  });

  final String ownerName;
  final String businessName;
  final String businessType;
  final String phone;
  final String address;
  final String city;
  final String currency;
  final File? logo;
}

final businessSetupProvider =
    NotifierProvider<BusinessSetupNotifier, BusinessSetupState>(
      BusinessSetupNotifier.new,
    );

class BusinessSetupNotifier extends Notifier<BusinessSetupState> {
  @override
  BusinessSetupState build() => const BusinessSetupState();

  Future<void> create(BusinessSetupInput input) async {
    if (state.isLoading || state.status == BusinessSetupStatus.success) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const BusinessSetupState(
        status: BusinessSetupStatus.error,
        message: 'Your session expired. Please sign in again.',
      );
      return;
    }
    final phone = normalizePakistanPhone(input.phone);
    if (phone == null) {
      state = const BusinessSetupState(
        status: BusinessSetupStatus.error,
        message: 'Enter a valid Pakistani mobile number.',
      );
      return;
    }

    try {
      final repository = ref.read(businessRepositoryProvider);
      final businessId = repository.newBusinessId();
      var logoUrl = '';
      if (input.logo != null) {
        state = const BusinessSetupState(status: BusinessSetupStatus.uploading);
        logoUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/$businessId/logo/business_logo.jpg',
              file: input.logo!,
              onProgress: (progress) {
                state = BusinessSetupState(
                  status: BusinessSetupStatus.uploading,
                  uploadProgress: progress,
                );
              },
            );
      }

      state = BusinessSetupState(
        status: BusinessSetupStatus.saving,
        uploadProgress: input.logo == null ? 0 : 1,
      );
      await repository.createWithUserSelection(
        BusinessModel(
          id: businessId,
          ownerId: user.uid,
          ownerName: input.ownerName.trim(),
          businessName: input.businessName.trim(),
          businessType: input.businessType,
          phone: phone,
          address: input.address.trim(),
          city: input.city.trim(),
          currency: input.currency,
          logoUrl: logoUrl,
          totalReceivable: 0,
          totalPayable: 0,
          cashBalance: 0,
          totalCashIn: 0,
          totalCashOut: 0,
        ),
      );
      state = BusinessSetupState(
        status: BusinessSetupStatus.success,
        uploadProgress: input.logo == null ? 0 : 1,
        businessId: businessId,
        message: 'Business created successfully.',
      );
    } catch (error) {
      final duplicate = error.toString().contains('already exists');
      state = BusinessSetupState(
        status: BusinessSetupStatus.error,
        message: duplicate
            ? 'A business already exists for this account.'
            : 'Could not create your business. Please try again.',
      );
    }
  }
}
