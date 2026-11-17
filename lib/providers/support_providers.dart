import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/support_launcher_service.dart';
import '../models/support_request_model.dart';
import '../repositories/support_repository.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final supportLauncherProvider = Provider((_) => SupportLauncherService());

final supportRepositoryProvider = Provider(
  (ref) => SupportRepository(
    ref.watch(storageRepositoryProvider),
  ),
);

final appVersionProvider = FutureProvider(
  (ref) => ref.watch(supportLauncherProvider).appVersion(),
);

class SupportSubmissionState {
  const SupportSubmissionState({
    this.submitting = false,
    this.progress = 0,
    this.success = false,
    this.requestId,
    this.error,
  });

  final bool submitting;
  final double progress;
  final bool success;
  final String? requestId;
  final String? error;
}

final supportSubmissionProvider =
    NotifierProvider<SupportSubmissionNotifier, SupportSubmissionState>(
      SupportSubmissionNotifier.new,
    );

class SupportSubmissionNotifier extends Notifier<SupportSubmissionState> {
  @override
  SupportSubmissionState build() => const SupportSubmissionState();

  Future<bool> submit({
    required String subject,
    required String category,
    required String description,
    File? screenshot,
  }) async {
    if (state.submitting) return false;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) {
      state = const SupportSubmissionState(
        error: 'Sign in and select a business before requesting support.',
      );
      return false;
    }
    state = const SupportSubmissionState(submitting: true);
    try {
      final deviceInfo = await ref
          .read(supportLauncherProvider)
          .privacySafeDeviceInfo();
      final id = await ref
          .read(supportRepositoryProvider)
          .submit(
            request: SupportRequestModel(
              id: '',
              ownerId: user.uid,
              businessId: business.id,
              subject: subject,
              category: category,
              description: description,
              screenshotUrl: '',
              deviceInfo: deviceInfo,
              status: 'open',
            ),
            screenshot: screenshot,
            onProgress: (progress) {
              state = SupportSubmissionState(
                submitting: true,
                progress: progress,
              );
            },
          );
      state = SupportSubmissionState(progress: 1, success: true, requestId: id);
      return true;
    } catch (error) {
      state = SupportSubmissionState(error: _supportError(error));
      return false;
    }
  }

  void reset() => state = const SupportSubmissionState();
}

String _supportError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission')) {
    return 'You do not have permission to submit this request.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  return 'Support request could not be submitted. Please try again.';
}
