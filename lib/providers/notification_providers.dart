import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification_model.dart';
import '../repositories/notification_repository.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(),
);

final notificationsProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return const Stream.empty();
  return ref
      .watch(notificationRepositoryProvider)
      .watchNotifications(ownerId: user.uid, businessId: business.id);
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return Stream.value(0);
  return ref
      .watch(notificationRepositoryProvider)
      .watchUnreadCount(ownerId: user.uid, businessId: business.id);
});
