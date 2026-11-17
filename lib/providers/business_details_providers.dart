import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_model.dart';
import 'auth_providers.dart';
import 'business_providers.dart';
import 'app_providers.dart';

class BusinessDetailsInput {
  const BusinessDetailsInput({
    required this.ownerName,
    required this.businessName,
    required this.businessType,
    required this.phone,
    required this.address,
    required this.city,
    required this.currency,
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

class BusinessDetailsActionState {
  const BusinessDetailsActionState({
    this.isSaving = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
  });

  final bool isSaving;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  bool get isBusy => isSaving || isUploading;
}

final businessDetailsActionProvider =
    NotifierProvider<BusinessDetailsNotifier, BusinessDetailsActionState>(
      BusinessDetailsNotifier.new,
    );

class BusinessDetailsNotifier extends Notifier<BusinessDetailsActionState> {
  @override
  BusinessDetailsActionState build() => const BusinessDetailsActionState();

  Future<bool> save(BusinessDetailsInput input) async {
    if (state.isBusy) return false;
    final user = ref.read(currentUserProvider);
    final current = ref.read(currentBusinessProvider).value;
    if (user == null || current == null) {
      state = const BusinessDetailsActionState(
        error: 'Business details are not available.',
      );
      return false;
    }
    final phone = normalizePakistanPhone(input.phone);
    if (phone == null) {
      state = const BusinessDetailsActionState(
        error: 'Enter a valid Pakistani mobile number.',
      );
      return false;
    }

    var logoUrl = current.logoUrl;
    String? uploadedUrl;
    try {
      if (input.logo != null) {
        state = const BusinessDetailsActionState(isUploading: true);
        uploadedUrl = await ref
            .read(storageRepositoryProvider)
            .uploadWithProgress(
              path:
                  'users/${user.uid}/businesses/${current.id}/logo/'
                  'business_logo_${DateTime.now().microsecondsSinceEpoch}.jpg',
              file: input.logo!,
              onProgress: (progress) {
                state = BusinessDetailsActionState(
                  isUploading: true,
                  uploadProgress: progress,
                );
              },
            );
        logoUrl = uploadedUrl;
      }

      state = BusinessDetailsActionState(
        isSaving: true,
        uploadProgress: input.logo == null ? 0 : 1,
      );
      await ref
          .read(businessRepositoryProvider)
          .updateEditable(
            BusinessModel(
              id: current.id,
              ownerId: user.uid,
              ownerName: input.ownerName.trim(),
              businessName: input.businessName.trim(),
              businessType: input.businessType.trim(),
              phone: phone,
              address: input.address.trim(),
              city: input.city.trim(),
              currency: input.currency.trim(),
              logoUrl: logoUrl,
            ),
          );

      if (uploadedUrl != null &&
          current.logoUrl.isNotEmpty &&
          current.logoUrl != uploadedUrl) {
        try {
          await ref
              .read(storageRepositoryProvider)
              .deleteByUrl(current.logoUrl);
        } catch (_) {
          // Database already points to the replacement. Old-file cleanup is
          // best effort and must not turn a completed save into a failed save.
        }
      }
      state = const BusinessDetailsActionState();
      return true;
    } catch (error) {
      if (uploadedUrl != null) {
        try {
          await ref.read(storageRepositoryProvider).deleteByUrl(uploadedUrl);
        } catch (_) {}
      }
      state = BusinessDetailsActionState(error: _businessError(error));
      return false;
    }
  }
}

String _businessError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission')) {
    return 'You do not have permission to update this business.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  return 'Could not save business details. Please try again.';
}
