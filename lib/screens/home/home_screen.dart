import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes/app_routes.dart';
import '../../models/dashboard_model.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/main_navigation_providers.dart';
import '../../providers/notification_providers.dart';

const _blue = Color(0xFF1239B0);
const _green = Color(0xFF00A86B);
const _red = Color(0xFFE53935);
const _page = Color(0xFFF6F8FC);
const _border = Color(0xFFDDE2EE);
const _shadow = Color(0x0A101828);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : _page,
      child: SafeArea(
        bottom: false,
        child: dashboard.when(
          loading: () => const _DashboardSkeleton(),
          error: (error, _) => _DashboardError(
            message: _errorMessage(error),
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: _DashboardContent(data: data),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Dashboard access was denied. Please sign in again.';
    }
    if (text.contains('network') || text.contains('unavailable')) {
      return 'Could not load data. Please try again.';
    }
    return 'Could not load your dashboard.';
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.data});
  final DashboardModel data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 28),
      children: [
        _Header(
          ownerName: data.ownerName,
          businessName: data.businessName,
          imageUrl: data.logoUrl,
          unread: unread,
          onNotifications: () => context.push(AppRoutes.notifications),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 124,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              SizedBox(
                width: 230,
                child: _BalanceCard(
                  label: 'YOU WILL RECEIVE',
                  amount: data.totalReceivable,
                  detail: 'From ${data.totalCustomers} Customers',
                  color: _green,
                  icon: Icons.south_rounded,
                  currency: data.currency,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 230,
                child: _BalanceCard(
                  label: 'YOU WILL PAY',
                  amount: data.totalPayable,
                  detail: 'To ${data.totalSuppliers} Suppliers',
                  color: _red,
                  icon: Icons.north_rounded,
                  currency: data.currency,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickAction(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Add\nCustomer',
              color: _blue,
              onTap: () => context.push(AppRoutes.addCustomer),
            ),
            _QuickAction(
              icon: Icons.north_east_rounded,
              label: 'You Gave',
              color: _red,
              onTap: () => context.push(
                AppRoutes.addTransaction,
                extra: const <String, dynamic>{'type': 'gave'},
              ),
            ),
            _QuickAction(
              icon: Icons.south_west_rounded,
              label: 'You\nReceived',
              color: _green,
              onTap: () => context.push(
                AppRoutes.addTransaction,
                extra: const <String, dynamic>{'type': 'received'},
              ),
            ),
            _QuickAction(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Cash Entry',
              color: _blue,
              onTap: () => context.push(AppRoutes.addCashEntry),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Business Summary'),
        const SizedBox(height: 11),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.05,
          children: [
            _SmallSummary(
              label: 'Cash In (Today)',
              value: _money(data.totalCashIn, data.currency),
              color: _green,
            ),
            _SmallSummary(
              label: 'Cash Out (Today)',
              value: _money(data.totalCashOut, data.currency),
              color: _red,
            ),
            _SmallSummary(
              label: 'Total Customers',
              value: data.totalCustomers.toString(),
            ),
            _SmallSummary(
              label: 'Total Suppliers',
              value: data.totalSuppliers.toString(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          'Recent Transactions',
          action: 'View All',
          onTap: () => ref.read(mainNavigationIndexProvider.notifier).select(2),
        ),
        const SizedBox(height: 9),
        _RecentTransactions(
          transactions: data.recentTransactions,
          currency: data.currency,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.ownerName,
    required this.businessName,
    required this.imageUrl,
    required this.unread,
    required this.onNotifications,
  });
  final String ownerName;
  final String businessName;
  final String imageUrl;
  final int unread;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final name = ownerName.trim().isEmpty
        ? 'Business Owner'
        : ownerName.trim().split(' ').first;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFDDE7FF),
          backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
          child: imageUrl.isEmpty
              ? Text(
                  _initials(businessName),
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: const TextStyle(fontSize: 9, color: Color(0xFF667085)),
              ),
              Text(
                businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onNotifications,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _blue,
                size: 20,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.detail,
    required this.color,
    required this.icon,
    required this.currency,
  });
  final String label;
  final double amount;
  final String detail;
  final Color color;
  final IconData icon;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    height: 124,
    decoration: BoxDecoration(
      color: _homeCardColor(context),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(9),
      boxShadow: const [
        BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 3)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _money(amount, currency),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            detail,
            style: const TextStyle(fontSize: 9, color: Color(0xFF667085)),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onTap,
          child: Text(action!, style: const TextStyle(fontSize: 8)),
        ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withValues(alpha: .08)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, height: 1.15),
          ),
        ],
      ),
    ),
  );
}

class _SmallSummary extends StatelessWidget {
  const _SmallSummary({
    required this.label,
    required this.value,
    this.color = const Color(0xFF101828),
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _homeCardColor(context),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(9),
      boxShadow: const [
        BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.transactions,
    required this.currency,
  });
  final List<DashboardTransaction> transactions;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              const Text('No recent transactions'),
            ],
          ),
        ),
      );
    }
    return Material(
      color: _homeCardColor(context),
      elevation: 1,
      shadowColor: _shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: _border),
      ),
      child: Column(
        children: transactions.take(3).map((transaction) {
          final received = transaction.type != 'gave';
          return ListTile(
            dense: true,
            minTileHeight: 72,
            minVerticalPadding: 5,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const Border(bottom: BorderSide(color: _border, width: .6)),
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFEAF0FF),
              child: Text(
                _initials(transaction.customerName),
                style: const TextStyle(
                  color: _blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              transaction.customerName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              DateFormat('dd MMM, hh:mm a').format(transaction.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${received ? '+' : '-'} ${_money(transaction.amount, currency)}',
                  style: TextStyle(
                    color: received ? _green : _red,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  received ? 'RECEIVED' : 'GAVE',
                  style: TextStyle(
                    color: received ? _green : _red,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(14),
    children: List.generate(
      7,
      (index) => Container(
        height: index == 0 ? 55 : 92,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(30, 150, 30, 30),
    children: [
      Icon(
        Icons.cloud_off_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(height: 14),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    ],
  );
}

String _money(double value, String currency) => NumberFormat.currency(
  symbol: currency == 'PKR' ? '₨ ' : '$currency ',
  decimalDigits: 2,
).format(value);

Color _homeCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? Colors.white
    : Theme.of(context).colorScheme.surfaceContainer;

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'SK';
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}
