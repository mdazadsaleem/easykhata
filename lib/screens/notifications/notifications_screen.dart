import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes/app_routes.dart';
import '../../models/app_notification_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/notification_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _red = Color(0xFFD71920);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _page = Color(0xFFF8F9FD);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final items = notifications.value ?? const <AppNotificationModel>[];

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: items.any((item) => !item.isRead)
                ? () => _markAllRead(context, ref)
                : null,
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _NotificationsError(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) => _NotificationsList(items: items),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .markAllAsRead(ownerId: user.uid, businessId: business.id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.items});
  final List<AppNotificationModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = items
        .where((item) => DateTime.now().difference(item.createdAt).inDays < 2)
        .toList();
    final earlier = items
        .where((item) => DateTime.now().difference(item.createdAt).inDays >= 2)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 25),
        children: [
          if (items.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmClearAll(context, ref),
                icon: const Icon(Icons.clear_all_rounded, size: 14),
                label: const Text('Clear all'),
                style: TextButton.styleFrom(
                  foregroundColor: _red,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            const _EmptyNotifications()
          else ...[
            if (recent.isNotEmpty) ...[
              const _SectionLabel('RECENT'),
              ...recent.map(
                (item) => _NotificationCard(
                  item: item,
                  onTap: () => _open(context, ref, item),
                  onDelete: () => _delete(context, ref, item),
                ),
              ),
            ],
            if (earlier.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionLabel('EARLIER'),
              ...earlier.map(
                (item) => _NotificationCard(
                  item: item,
                  onTap: () => _open(context, ref, item),
                  onDelete: () => _delete(context, ref, item),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotificationModel item,
  ) async {
    try {
      await ref.read(notificationRepositoryProvider).markAsRead(item);
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return;
    }
    if (!context.mounted) return;
    final referenceId = item.referenceId?.trim();
    switch (item.type) {
      case AppNotificationType.paymentReminder:
      case AppNotificationType.overduePayment:
        if (referenceId != null && referenceId.isNotEmpty) {
          context.push('${AppRoutes.customerDetails}/$referenceId');
        } else {
          context.push(AppRoutes.reminders);
        }
      case AppNotificationType.backupCompletion:
        context.push(AppRoutes.backupRestore);
      case AppNotificationType.businessAlert:
        context.push(AppRoutes.businessDetails);
      case AppNotificationType.generalAnnouncement:
        break;
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppNotificationModel item,
  ) async {
    try {
      await ref.read(notificationRepositoryProvider).delete(item);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will permanently delete every notification for this business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _red),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .clearAll(ownerId: user.uid, businessId: business.id);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 7),
    child: Text(
      label,
      style: const TextStyle(
        color: _muted,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });
  final AppNotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color get _color => switch (item.type) {
    AppNotificationType.paymentReminder => _blue,
    AppNotificationType.overduePayment => _red,
    AppNotificationType.backupCompletion => _green,
    AppNotificationType.businessAlert => const Color(0xFFF79009),
    AppNotificationType.generalAnnouncement => const Color(0xFF6941C6),
  };

  IconData get _icon => switch (item.type) {
    AppNotificationType.paymentReminder =>
      Icons.account_balance_wallet_outlined,
    AppNotificationType.overduePayment => Icons.warning_amber_rounded,
    AppNotificationType.backupCompletion => Icons.cloud_done_outlined,
    AppNotificationType.businessAlert => Icons.business_outlined,
    AppNotificationType.generalAnnouncement => Icons.campaign_outlined,
  };

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(item.id),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async => true,
    onDismissed: (_) => onDelete(),
    background: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(right: 18),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.isRead ? _border : _blue),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 10,
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(item.createdAt),
                          style: const TextStyle(color: _muted, fontSize: 7),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          onSelected: (_) => onDelete(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 8,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt)}'
                      '  •  ${item.isRead ? 'Read' : 'Unread'}',
                      style: TextStyle(
                        color: item.isRead ? _muted : _blue,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 100),
    child: Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFE8EEFF),
          child: Icon(Icons.notifications_none_rounded, color: _blue, size: 31),
        ),
        SizedBox(height: 14),
        Text(
          'You’re all caught up',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'New account activity will appear here.',
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _red, size: 45),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _relativeTime(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.isNegative || difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat('dd MMM').format(date);
}

String _errorMessage(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('permission')) {
    return 'Notification access was denied. Please sign in again.';
  }
  if (message.contains('network') || message.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  return 'Could not load notifications.';
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
}
