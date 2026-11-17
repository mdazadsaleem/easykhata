import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes/app_routes.dart';
import '../../models/customer_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/customer_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  static const _tabs = ['All', 'Customers', 'Suppliers', 'Settled'];

  Future<void> _refresh() async {
    ref.invalidate(customersProvider);
    await ref.read(customersProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = ref.watch(visibleCustomersProvider);
    final filters = ref.watch(customerFiltersProvider);
    final summary = ref.watch(customerBalanceSummaryProvider);
    final business = ref.watch(currentBusinessProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 10,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF294DC0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _initials(business?.businessName ?? 'Smart Khata'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Customers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: ref.read(customerFiltersProvider.notifier).search,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF7C879A),
                    fontSize: 11.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Filter customers',
                    onPressed: _showFilters,
                    icon: const Icon(Icons.tune_rounded, size: 19),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F4FA),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFD5DBE7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFD5DBE7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Color(0xFF1749CD),
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _CustomerTabs(
            labels: _tabs,
            selected: filters.tab.index,
            onSelected: (index) => ref
                .read(customerFiltersProvider.notifier)
                .selectTab(CustomerTab.values[index]),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: _BalanceSummary(
                    title: "You'll Receive",
                    amount: summary.$1,
                    color: const Color(0xFF14A56B),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _BalanceSummary(
                    title: "You'll Pay",
                    amount: summary.$2,
                    color: const Color(0xFFD92F3C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filteredCustomers.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 75),
                        Icon(
                          Icons.people_outline_rounded,
                          size: 54,
                          color: Color(0xFF9CA8BC),
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No customers found',
                            style: TextStyle(
                              color: Color(0xFF536078),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 82),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) => _CustomerCard(
                      customer: customers[index],
                      onTap: () => context.push(
                        '${AppRoutes.customerDetails}/${customers[index].id}',
                      ),
                      onEdit: () => context.push(
                        '${AppRoutes.editCustomer}/${customers[index].id}',
                      ),
                      onDelete: () => _deleteCustomer(customers[index]),
                      onCall: () => _call(customers[index]),
                      onWhatsApp: () => _whatsApp(customers[index]),
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0733A2),
                  strokeWidth: 2.5,
                ),
              ),
              error: (_, _) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 75),
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Color(0xFF9CA8BC),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Could not load customers. Pull to retry.',
                        style: TextStyle(color: Color(0xFF536078)),
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(customersProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 44,
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0733A2),
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: () => context.push(AppRoutes.addCustomer),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text(
              'Add Customer',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    final notifier = ref.read(customerFiltersProvider.notifier);
    final current = ref.read(customerFiltersProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort & filter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sort by',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              DropdownButtonFormField<CustomerSort>(
                initialValue: current.sort,
                items: CustomerSort.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_sortLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) notifier.selectSort(value);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Balance',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 7,
                children: CustomerBalanceFilter.values
                    .map(
                      (value) => ChoiceChip(
                        label: Text(_balanceLabel(value)),
                        selected: current.balance == value,
                        onSelected: (_) {
                          notifier.selectBalance(value);
                          context.pop();
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _call(CustomerModel customer) async {
    if (customer.phone.isEmpty) {
      _message('This customer has no phone number.');
      return;
    }
    final normalized = customer.phone.startsWith('+')
        ? customer.phone
        : '+92${customer.phone.replaceFirst(RegExp(r'^0'), '')}';
    await launchUrl(Uri.parse('tel:$normalized'));
  }

  Future<void> _whatsApp(CustomerModel customer) async {
    if (customer.phone.isEmpty) {
      _message('This customer has no phone number.');
      return;
    }
    var digits = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (!digits.startsWith('92')) digits = '92$digits';
    final opened = await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _message('WhatsApp could not be opened.');
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final hasTransactions = await ref
        .read(customerActionProvider.notifier)
        .hasTransactions(customer);
    if (!mounted) return;
    final archive = hasTransactions;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archive ? 'Archive customer?' : 'Delete customer?'),
        content: Text(
          archive
              ? '${customer.name} has ledger transactions and cannot be '
                    'permanently deleted safely. Archive the account instead?'
              : 'Delete ${customer.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(archive ? 'Archive' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(customerActionProvider.notifier)
        .delete(customer, archive: archive);
    if (!mounted) return;
    final result = ref.read(customerActionProvider);
    _message(
      result.hasError
          ? 'Could not update customer: ${result.error}'
          : archive
          ? 'Customer archived safely.'
          : 'Customer deleted.',
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CustomerTabs extends StatelessWidget {
  const _CustomerTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFDDE2EB))),
    ),
    child: Row(
      children: List.generate(
        labels.length,
        (index) => Expanded(
          child: InkWell(
            onTap: () => onSelected(index),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == selected
                        ? const Color(0xFF1749CD)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: index == selected
                      ? const Color(0xFF1749CD)
                      : const Color(0xFF596579),
                  fontSize: 9.5,
                  fontWeight: index == selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.title,
    required this.amount,
    required this.color,
  });

  final String title;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 59,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4FA),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD4DBE8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFF536078), fontSize: 9),
        ),
        const SizedBox(height: 4),
        Text(
          '₨ ${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
    required this.onWhatsApp,
  });

  final CustomerModel customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final isReceive = customer.currentBalance > 0.005;
    final isPay = customer.currentBalance < -0.005;
    final color = isReceive
        ? const Color(0xFF13A66C)
        : isPay
        ? const Color(0xFFD92F3C)
        : const Color(0xFF667085);
    final status = isReceive
        ? 'RECEIVE'
        : isPay
        ? 'PAY'
        : 'SETTLED';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: Color(0xFFE0E4EC)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFEDF1FF),
                  backgroundImage: customer.profileImage.isEmpty
                      ? null
                      : NetworkImage(customer.profileImage),
                  child: customer.profileImage.isEmpty
                      ? Text(
                          _initials(customer.name),
                          style: const TextStyle(
                            color: Color(0xFF1749CD),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF07152B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.phone.isEmpty
                            ? 'No phone number'
                            : customer.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 8.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last entry: ${_relativeDate(customer.lastTransactionAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 7.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₨ ${NumberFormat('#,##0.00').format(customer.currentBalance.abs())}',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (value) => switch (value) {
                    'edit' => onEdit(),
                    'call' => onCall(),
                    'whatsapp' => onWhatsApp(),
                    'delete' => onDelete(),
                    _ => null,
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'call', child: Text('Call')),
                    PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length.clamp(1, 2))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _relativeDate(DateTime? date) {
  if (date == null) return 'No transactions';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hrs ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return DateFormat('d MMM').format(date);
}

String _sortLabel(CustomerSort value) => switch (value) {
  CustomerSort.name => 'Name',
  CustomerSort.highestBalance => 'Highest balance',
  CustomerSort.lowestBalance => 'Lowest balance',
  CustomerSort.recentlyAdded => 'Recently added',
  CustomerSort.lastTransaction => 'Last transaction',
};

String _balanceLabel(CustomerBalanceFilter value) => switch (value) {
  CustomerBalanceFilter.all => 'All',
  CustomerBalanceFilter.receivable => 'Receivable',
  CustomerBalanceFilter.payable => 'Payable',
  CustomerBalanceFilter.settled => 'Settled',
};
