import '../core/database/hive_database.dart';
import '../models/app_notification_model.dart';

class NotificationRepository {
  NotificationRepository();

  Stream<List<AppNotificationModel>> watchNotifications({
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.notificationsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final list = box.values
            .map((e) => AppNotificationModel.fromMap(
                Map<String, dynamic>.from(e), e['id']))
            .where((n) => n.ownerId == ownerId && n.businessId == businessId)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(list);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<int> watchUnreadCount({
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.notificationsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final count = box.values.where((e) {
          final data = Map<String, dynamic>.from(e);
          return data['ownerId'] == ownerId &&
              data['businessId'] == businessId &&
              data['isRead'] != true;
        }).length;
        controller.add(count);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<void> markAsRead(AppNotificationModel notification) async {
    if (notification.isRead) return;
    final box = HiveDatabase.instance.notificationsBox;
    final data = box.get(notification.id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final now = DateTime.now().toIso8601String();
      map['isRead'] = true;
      map['readAt'] = now;
      map['updatedAt'] = now;
      await box.put(notification.id, map);
    }
  }

  Future<void> markAllAsRead({
    required String ownerId,
    required String businessId,
  }) async {
    final box = HiveDatabase.instance.notificationsBox;
    final now = DateTime.now().toIso8601String();
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['ownerId'] == ownerId &&
            map['businessId'] == businessId &&
            map['isRead'] != true) {
          map['isRead'] = true;
          map['readAt'] = now;
          map['updatedAt'] = now;
          await box.put(key, map);
        }
      }
    }
  }

  Future<void> delete(AppNotificationModel notification) async {
    final box = HiveDatabase.instance.notificationsBox;
    await box.delete(notification.id);
  }

  Future<void> clearAll({
    required String ownerId,
    required String businessId,
  }) async {
    final box = HiveDatabase.instance.notificationsBox;
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['ownerId'] == ownerId && map['businessId'] == businessId) {
          keysToDelete.add(key);
        }
      }
    }
    await box.deleteAll(keysToDelete);
  }
}
