import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business_model.dart';
import 'app_providers.dart';

final currentBusinessProvider = StreamProvider<BusinessModel?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream.empty();
  if (auth.hasError) return Stream.error(auth.error!);
  final user = auth.value;
  if (user == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(businessRepositoryProvider);
  return (() async* {
    try {
      final businessId = await repository.selectedBusinessId(user.uid);
      yield* repository.watchById(businessId: businessId, ownerId: user.uid);
    } catch (_) {
      yield null;
    }
  })();
});
