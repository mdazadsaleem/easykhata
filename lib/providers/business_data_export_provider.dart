import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/business_data_export_service.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final businessDataExportServiceProvider = Provider(
  (ref) => BusinessDataExportService(),
);

final businessDataExportProvider =
    AsyncNotifierProvider<BusinessDataExportNotifier, void>(
      BusinessDataExportNotifier.new,
    );

class BusinessDataExportNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> export() async {
    if (state.isLoading) return false;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) return false;
    state = const AsyncLoading();
    try {
      final service = ref.read(businessDataExportServiceProvider);
      final file = await service.createBackup(
        ownerId: user.uid,
        businessId: business.id,
      );
      await service.shareBackup(file);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
