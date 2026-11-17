import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_model.dart';
import '../models/reminder_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final remindersProvider = StreamProvider<List<ReminderModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return Stream.value([]);
  return ref.watch(reminderRepositoryProvider).watch(user.uid, business.id);
});

final reminderNotificationSyncProvider = FutureProvider<void>((ref) async {
  final reminders = await ref.watch(remindersProvider.future);
  final service = ref.watch(localNotificationServiceProvider);
  for (final reminder in reminders) {
    if (reminder.isCompleted) {
      await service.cancel(reminder.notificationId);
    } else if (reminder.dueDate.isAfter(DateTime.now())) {
      await service.schedule(
        id: reminder.notificationId,
        customerName: reminder.customerName,
        message: reminder.message,
        dueDate: reminder.dueDate,
      );
    }
  }
});

enum ReminderMutationStatus { idle, saving, deleting, success, error }

class ReminderMutationState {
  const ReminderMutationState({
    this.status = ReminderMutationStatus.idle,
    this.errorMessage,
  });
  final ReminderMutationStatus status;
  final String? errorMessage;
  bool get isLoading =>
      status == ReminderMutationStatus.saving ||
      status == ReminderMutationStatus.deleting;
}

final reminderMutationProvider =
    NotifierProvider<ReminderMutationNotifier, ReminderMutationState>(
      ReminderMutationNotifier.new,
    );

class ReminderMutationNotifier extends Notifier<ReminderMutationState> {
  @override
  ReminderMutationState build() => const ReminderMutationState();

  Future<bool> save({
    ReminderModel? existing,
    required CustomerModel customer,
    required double amount,
    required String message,
    required DateTime dueDate,
  }) async {
    if (state.isLoading) return false;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null ||
        business == null ||
        customer.ownerId != user.uid ||
        customer.businessId != business.id ||
        amount <= 0) {
      state = const ReminderMutationState(
        status: ReminderMutationStatus.error,
        errorMessage: 'Reminder details or business access are invalid.',
      );
      return false;
    }
    state = const ReminderMutationState(status: ReminderMutationStatus.saving);
    final repository = ref.read(reminderRepositoryProvider);
    final service = ref.read(localNotificationServiceProvider);
    final id = existing?.id ?? repository.newId();
    final notificationId =
        existing?.notificationId ?? (id.hashCode & 0x7fffffff);
    final reminder = ReminderModel(
      id: id,
      ownerId: user.uid,
      businessId: business.id,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phone,
      amount: amount,
      message: message.trim(),
      dueDate: dueDate,
      status: existing?.status == 'completed'
          ? 'upcoming'
          : existing?.status ?? 'upcoming',
      notificationId: notificationId,
      createdAt: existing?.createdAt,
    );
    try {
      if (existing != null) await service.cancel(notificationId);
      await service.schedule(
        id: notificationId,
        customerName: customer.name,
        message: reminder.message,
        dueDate: dueDate,
      );
      if (existing == null) {
        await repository.create(reminder);
      } else {
        await repository.update(reminder);
      }
      state = const ReminderMutationState(
        status: ReminderMutationStatus.success,
      );
      return true;
    } catch (_) {
      await service.cancel(notificationId);
      if (existing != null && existing.dueDate.isAfter(DateTime.now())) {
        try {
          await service.schedule(
            id: existing.notificationId,
            customerName: existing.customerName,
            message: existing.message,
            dueDate: existing.dueDate,
          );
        } catch (_) {}
      }
      state = const ReminderMutationState(
        status: ReminderMutationStatus.error,
        errorMessage: 'Could not save or schedule this reminder.',
      );
      return false;
    }
  }

  Future<bool> markSent(ReminderModel reminder) =>
      _setStatus(reminder, 'sent', cancel: false);

  Future<bool> complete(ReminderModel reminder) =>
      _setStatus(reminder, 'completed', cancel: true);

  Future<bool> _setStatus(
    ReminderModel reminder,
    String status, {
    required bool cancel,
  }) async {
    if (state.isLoading) return false;
    state = const ReminderMutationState(status: ReminderMutationStatus.saving);
    try {
      await ref.read(reminderRepositoryProvider).setStatus(reminder, status);
      if (cancel) {
        await ref
            .read(localNotificationServiceProvider)
            .cancel(reminder.notificationId);
      }
      state = const ReminderMutationState(
        status: ReminderMutationStatus.success,
      );
      return true;
    } catch (_) {
      state = const ReminderMutationState(
        status: ReminderMutationStatus.error,
        errorMessage: 'Could not update this reminder.',
      );
      return false;
    }
  }

  Future<bool> delete(ReminderModel reminder) async {
    if (state.isLoading) return false;
    state = const ReminderMutationState(
      status: ReminderMutationStatus.deleting,
    );
    try {
      await ref.read(reminderRepositoryProvider).delete(reminder);
      await ref
          .read(localNotificationServiceProvider)
          .cancel(reminder.notificationId);
      state = const ReminderMutationState(
        status: ReminderMutationStatus.success,
      );
      return true;
    } catch (_) {
      state = const ReminderMutationState(
        status: ReminderMutationStatus.error,
        errorMessage: 'Could not delete this reminder.',
      );
      return false;
    }
  }
}
