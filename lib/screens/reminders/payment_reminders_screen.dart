import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes/app_routes.dart';
import '../../models/customer_model.dart';
import '../../models/reminder_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/customer_providers.dart';
import '../../providers/reminder_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _red = Color(0xFFD71920);
const _orange = Color(0xFFF79009);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _page = Color(0xFFF8F9FD);

enum _ReminderTab { upcoming, sent, overdue, completed }

class PaymentRemindersScreen extends ConsumerStatefulWidget {
  const PaymentRemindersScreen({super.key});

  @override
  ConsumerState<PaymentRemindersScreen> createState() =>
      _PaymentRemindersScreenState();
}

class _PaymentRemindersScreenState
    extends ConsumerState<PaymentRemindersScreen> {
  _ReminderTab _tab = _ReminderTab.upcoming;

  Future<void> _sendWhatsApp(ReminderModel reminder) async {
    var phone = reminder.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('92')) phone = '92$phone';
    if (phone.length < 12) {
      _message('This customer has no valid WhatsApp number.');
      return;
    }
    final opened = await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(reminder.message)}',
      ),
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      await ref.read(reminderMutationProvider.notifier).markSent(reminder);
    }
  }

  Future<void> _sendSms(ReminderModel reminder) async {
    final phone = reminder.customerPhone.trim();
    if (phone.isEmpty) {
      _message('This customer has no phone number.');
      return;
    }
    final opened = await launchUrl(
      Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': reminder.message},
      ),
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      await ref.read(reminderMutationProvider.notifier).markSent(reminder);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _showReminderForm([ReminderModel? existing]) async {
    final customers = ref.read(customersProvider).value ?? <CustomerModel>[];
    if (customers.isEmpty) {
      _message('Add a customer before creating a reminder.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    CustomerModel? customer = existing == null
        ? null
        : customers.where((item) => item.id == existing.customerId).firstOrNull;
    final amount = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    final message = TextEditingController(
      text:
          existing?.message ??
          'Hello, this is a friendly payment reminder from Smart Khata.',
    );
    var dueDate =
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add New Reminder' : 'Edit Reminder'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CustomerModel>(
                    initialValue: customer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: customers
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Select a customer.' : null,
                    onChanged: (value) =>
                        setDialogState(() => customer = value),
                  ),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      return parsed == null || parsed <= 0
                          ? 'Enter a positive amount.'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: message,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Message',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a reminder message.'
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date and Time'),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(dueDate),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dueDate),
                      );
                      if (time != null) {
                        setDialogState(
                          () => dueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final success = await ref
                    .read(reminderMutationProvider.notifier)
                    .save(
                      existing: existing,
                      customer: customer!,
                      amount: double.parse(amount.text.trim()),
                      message: message.text,
                      dueDate: dueDate,
                    );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, success);
                }
              },
              child: Text(existing == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    message.dispose();
    if (saved == true) {
      _message(
        existing == null
            ? 'Reminder created and notification scheduled.'
            : 'Reminder updated and rescheduled.',
      );
    }
  }

  Future<void> _reschedule(ReminderModel reminder) async {
    await _showReminderForm(reminder);
  }

  Future<void> _showActions(ReminderModel reminder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Send SMS'),
              onTap: () => Navigator.pop(context, 'sms'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Reschedule'),
              onTap: () => Navigator.pop(context, 'reschedule'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _red),
              title: const Text('Delete', style: TextStyle(color: _red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'sms') {
      await _sendSms(reminder);
    } else if (action == 'edit' || action == 'reschedule') {
      await _reschedule(reminder);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete reminder?'),
          content: const Text(
            'The scheduled local notification will also be cancelled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final deleted = await ref
            .read(reminderMutationProvider.notifier)
            .delete(reminder);
        _message(deleted ? 'Reminder deleted.' : 'Could not delete reminder.');
      }
    }
  }

  Future<void> _complete(ReminderModel reminder) async {
    final completed = await ref
        .read(reminderMutationProvider.notifier)
        .complete(reminder);
    _message(
      completed ? 'Reminder marked as paid.' : 'Could not complete reminder.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider).value;
    ref.watch(reminderNotificationSyncProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final reminders = remindersAsync.value ?? const <ReminderModel>[];
    final overdue = reminders.where((item) => item.isOverdue).toList();
    final upcoming = reminders
        .where(
          (item) =>
              !item.isCompleted && !item.isOverdue && item.status != 'sent',
        )
        .toList();
    final visible = switch (_tab) {
      _ReminderTab.upcoming => upcoming,
      _ReminderTab.sent =>
        reminders
            .where(
              (item) =>
                  item.status == 'sent' && !item.isCompleted && !item.isOverdue,
            )
            .toList(),
      _ReminderTab.overdue => overdue,
      _ReminderTab.completed =>
        reminders.where((item) => item.isCompleted).toList(),
    };
    final overdueTotal = overdue.fold<double>(
      0,
      (total, item) => total + item.amount,
    );
    final upcomingTotal = upcoming
        .where(
          (item) => item.dueDate.isBefore(
            DateTime.now().add(const Duration(days: 7)),
          ),
        )
        .fold<double>(0, (total, item) => total + item.amount);

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: _blue,
            size: 17,
          ),
        ),
        title: Text(
          business?.businessName ?? 'Smart Khata',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(remindersProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 95),
          children: [
            const Text(
              'Payment Reminders',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stay on top of your receivables',
              style: TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'TOTAL OVERDUE',
                    amount: overdueTotal,
                    color: _red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    label: 'UPCOMING (7D)',
                    amount: upcomingTotal,
                    color: _blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _Tabs(
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: 11),
            if (remindersAsync.isLoading && reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (remindersAsync.hasError)
              _ErrorState(onRetry: () => ref.invalidate(remindersProvider))
            else if (visible.isEmpty)
              _EmptyState(tab: _tab)
            else
              ...visible.map(
                (reminder) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ReminderCard(
                    reminder: reminder,
                    onName: () => context.push(
                      '${AppRoutes.customerDetails}/${reminder.customerId}',
                    ),
                    onWhatsApp: () => _sendWhatsApp(reminder),
                    onMarkPaid: () => _complete(reminder),
                    onActions: () => _showActions(reminder),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'addReminder',
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: _showReminderForm,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          _money(amount),
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});
  final _ReminderTab selected;
  final ValueChanged<_ReminderTab> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: _ReminderTab.values.map((tab) {
      final active = tab == selected;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(tab),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? _blue : _border,
                  width: active ? 2 : 1,
                ),
              ),
            ),
            child: Text(
              switch (tab) {
                _ReminderTab.upcoming => 'Upcoming',
                _ReminderTab.sent => 'Sent',
                _ReminderTab.overdue => 'Overdue',
                _ReminderTab.completed => 'Completed',
              },
              style: TextStyle(
                color: active ? _blue : _muted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onName,
    required this.onWhatsApp,
    required this.onMarkPaid,
    required this.onActions,
  });
  final ReminderModel reminder;
  final VoidCallback onName;
  final VoidCallback onWhatsApp;
  final VoidCallback onMarkPaid;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdue;
    final completed = reminder.isCompleted;
    final statusColor = completed
        ? _green
        : overdue
        ? _red
        : reminder.status == 'sent'
        ? _blue
        : _orange;
    return InkWell(
      onLongPress: onActions,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: statusColor.withValues(alpha: .12),
                  child: Text(
                    _initials(reminder.customerName),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onName,
                        child: Text(
                          reminder.customerName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reminder.customerPhone,
                        style: const TextStyle(color: _muted, fontSize: 7),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(reminder.dueDate),
                        style: TextStyle(color: statusColor, fontSize: 7),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(reminder.amount),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reminder.effectiveStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              reminder.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 8),
            ),
            const Divider(height: 17, color: Color(0xFFE8EBF2)),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: completed ? null : onWhatsApp,
                    icon: const Icon(Icons.send_outlined, size: 13),
                    label: const Text('Send WhatsApp'),
                    style: TextButton.styleFrom(
                      foregroundColor: _blue,
                      textStyle: const TextStyle(fontSize: 8),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: completed ? null : onMarkPaid,
                    icon: const Icon(Icons.check_circle_outline, size: 13),
                    label: const Text('Mark Paid'),
                    style: TextButton.styleFrom(
                      foregroundColor: _green,
                      textStyle: const TextStyle(fontSize: 8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onActions,
                  icon: const Icon(Icons.more_vert, size: 17),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});
  final _ReminderTab tab;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        const Icon(Icons.notifications_none_rounded, color: _blue, size: 32),
        const SizedBox(height: 9),
        Text(
          'No ${tab.name} reminders',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('Could not load payment reminders.'),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

String _money(double amount) => NumberFormat.currency(
  locale: 'en_PK',
  symbol: 'PKR ',
  decimalDigits: 2,
).format(amount);

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'C';
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}
