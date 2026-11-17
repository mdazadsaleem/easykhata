import '../core/database/hive_database.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  ReminderRepository();

  Stream<List<ReminderModel>> watch(String ownerId, String businessId) {
    final box = HiveDatabase.instance.remindersBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final reminders = box.values
            .map((e) =>
                ReminderModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((r) => r.ownerId == ownerId && r.businessId == businessId)
            .toList();
        reminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        controller.add(reminders);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  String newId() => 'rem_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> create(ReminderModel reminder) async {
    final box = HiveDatabase.instance.remindersBox;
    final now = DateTime.now().toIso8601String();
    final map = reminder.toMap()
      ..['id'] = reminder.id
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await box.put(reminder.id, map);
  }

  Future<void> update(ReminderModel reminder) async {
    final box = HiveDatabase.instance.remindersBox;
    final data = box.get(reminder.id);
    if (data == null) {
      throw StateError('Reminder not found.');
    }
    final now = DateTime.now().toIso8601String();
    final map = Map<String, dynamic>.from(data);
    map['customerId'] = reminder.customerId;
    map['customerName'] = reminder.customerName;
    map['customerPhone'] = reminder.customerPhone;
    map['amount'] = reminder.amount;
    map['message'] = reminder.message;
    map['dueDate'] = reminder.dueDate.toIso8601String();
    map['status'] = reminder.status;
    map['notificationId'] = reminder.notificationId;
    map['updatedAt'] = now;
    await box.put(reminder.id, map);
  }

  Future<void> setStatus(ReminderModel reminder, String status) async {
    final box = HiveDatabase.instance.remindersBox;
    final data = box.get(reminder.id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['status'] = status;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(reminder.id, map);
    }
  }

  Future<void> delete(ReminderModel reminder) async {
    final box = HiveDatabase.instance.remindersBox;
    await box.delete(reminder.id);
  }
}
