import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_model.dart';
import '../repositories/dashboard_repository.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(),
);

final dashboardProvider = StreamProvider<DashboardModel>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream.empty();
  if (auth.hasError) return Stream.error(auth.error!);
  final user = auth.value;
  if (user == null) {
    return Stream.error(StateError('No local user found.'));
  }

  final businessState = ref.watch(currentBusinessProvider);
  if (businessState.isLoading) return const Stream.empty();
  if (businessState.hasError) return Stream.error(businessState.error!);
  final business = businessState.value;
  if (business == null) {
    return const Stream.empty();
  }
  return ref
      .watch(dashboardRepositoryProvider)
      .watch(ownerId: user.uid, businessId: business.id);
});
