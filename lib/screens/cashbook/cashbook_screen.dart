import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes/app_routes.dart';
import '../../models/cashbook_entry_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/cashbook_providers.dart';
import '../../providers/app_providers.dart';

const _blue = Color(0xFF173EB5);
const _green = Color(0xFF009E60);
const _red = Color(0xFFD92D3A);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _page = Color(0xFFF8F9FD);

enum _CashPeriod { today, weekly, monthly, custom }

class CashbookScreen extends ConsumerStatefulWidget {
  const CashbookScreen({super.key});

  @override
  ConsumerState<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends ConsumerState<CashbookScreen> {
  final _searchController = TextEditingController();
  _CashPeriod _period = _CashPeriod.today;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (range == null || !mounted) return;
    setState(() {
      _customRange = range;
      _period = _CashPeriod.custom;
    });
    ref
        .read(cashbookFilterProvider.notifier)
        .set(
          ref
              .read(cashbookFilterProvider)
              .copyWith(period: CashbookPeriod.custom, customRange: range),
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final business = ref.watch(currentBusinessProvider).value;
    final entriesAsync = ref.watch(cashbookEntriesProvider);
    final view = ref.watch(cashbookViewProvider);

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentBusinessProvider);
            ref.invalidate(cashbookEntriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 9, 13, 25),
            children: [
              _Header(
                businessName: business?.businessName ?? 'Smart Khata',
                userName: user?.displayName ?? business?.ownerName ?? 'User',
                photoUrl: user?.photoURL,
              ),
              const SizedBox(height: 15),
              const Text(
                'Cashbook',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Manage your daily cash flow',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 13),
              _DateSelector(label: _dateLabel(view), onTap: _selectCustomRange),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BalanceCard(
                      label: 'Opening Balance',
                      amount: view.openingBalance,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _BalanceCard(
                      label: 'Closing Balance',
                      amount: view.closingBalance,
                      color: _green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _BalanceCard(
                      label: 'Cash In',
                      amount: view.cashIn,
                      color: _green,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _BalanceCard(
                      label: 'Cash Out',
                      amount: view.cashOut,
                      color: _red,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Add Cash In',
                      icon: Icons.add_circle_outline_rounded,
                      color: _green,
                      onTap: () =>
                          context.push(AppRoutes.addCashEntry, extra: 'cashIn'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _ActionButton(
                      label: 'Add Cash Out',
                      icon: Icons.remove_circle_outline_rounded,
                      color: _red,
                      onTap: () => context.push(
                        AppRoutes.addCashEntry,
                        extra: 'cashOut',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _PeriodSelector(
                value: _period,
                onSelected: (period) {
                  if (period == _CashPeriod.custom) {
                    _selectCustomRange();
                  } else {
                    setState(() => _period = period);
                    ref
                        .read(cashbookFilterProvider.notifier)
                        .set(
                          ref
                              .read(cashbookFilterProvider)
                              .copyWith(
                                period: switch (period) {
                                  _CashPeriod.today => CashbookPeriod.today,
                                  _CashPeriod.weekly => CashbookPeriod.weekly,
                                  _CashPeriod.monthly => CashbookPeriod.monthly,
                                  _CashPeriod.custom => CashbookPeriod.custom,
                                },
                              ),
                        );
                  }
                },
              ),
              const SizedBox(height: 11),
              TextField(
                controller: _searchController,
                onChanged: ref.read(cashbookFilterProvider.notifier).search,
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(fontSize: 11, color: _muted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: _muted,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _showAdvancedFilters,
                    icon: const Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: _muted,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${view.entries.length} entries',
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _TransactionList(
                entries: view.entries,
                loading: entriesAsync.isLoading,
                error: entriesAsync.hasError,
                onRetry: () => ref.invalidate(cashbookEntriesProvider),
                onTap: _showEntryActions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(CashbookViewData view) =>
      '${DateFormat('dd MMM yyyy').format(view.start)} - '
      '${DateFormat('dd MMM yyyy').format(view.end.subtract(const Duration(days: 1)))}';

  Future<void> _showAdvancedFilters() async {
    final current = ref.read(cashbookFilterProvider);
    String? category = current.category;
    String? payment = current.paymentMethod;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                    DropdownMenuItem(
                      value: 'Purchase',
                      child: Text('Purchase'),
                    ),
                    DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'Income', child: Text('Income')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) => setSheetState(() => category = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: payment,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Methods')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'Bank Transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'Easypaisa',
                      child: Text('Easypaisa'),
                    ),
                    DropdownMenuItem(
                      value: 'JazzCash',
                      child: Text('JazzCash'),
                    ),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) => setSheetState(() => payment = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(cashbookFilterProvider.notifier)
                          .set(
                            current.copyWith(
                              category: category,
                              clearCategory: category == null,
                              paymentMethod: payment,
                              clearPaymentMethod: payment == null,
                            ),
                          );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showEntryForm(
    String initialType, [
    CashbookEntryModel? existing,
  ]) async {
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your business is still loading.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final amount = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    var type = existing?.type ?? initialType;
    var category = existing?.category ?? 'Other';
    var payment = existing?.paymentMethod ?? 'Cash';
    var date = existing?.entryDate ?? DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Cash Entry' : 'Edit Cash Entry'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cashIn', label: Text('Cash In')),
                      ButtonSegment(value: 'cashOut', label: Text('Cash Out')),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) =>
                        setDialogState(() => type = value.first),
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
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                      DropdownMenuItem(
                        value: 'Purchase',
                        child: Text('Purchase'),
                      ),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(value: 'Income', child: Text('Income')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => category = value ?? 'Other',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('Bank Transfer'),
                      ),
                      DropdownMenuItem(
                        value: 'Easypaisa',
                        child: Text('Easypaisa'),
                      ),
                      DropdownMenuItem(
                        value: 'JazzCash',
                        child: Text('JazzCash'),
                      ),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => payment = value ?? 'Cash',
                  ),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date and Time'),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null) {
                        setDialogState(
                          () => date = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            date.hour,
                            date.minute,
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
                final entry = CashbookEntryModel(
                  id: existing?.id ?? '',
                  ownerId: user.uid,
                  businessId: business.id,
                  type: type,
                  amount: double.parse(amount.text.trim()),
                  category: category,
                  description: description.text.trim(),
                  paymentMethod: payment,
                  receiptUrl: existing?.receiptUrl ?? '',
                  entryDate: date,
                );
                final success = await ref
                    .read(cashbookMutationProvider.notifier)
                    .save(entry, edit: existing != null);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, success);
                }
              },
              child: Text(existing == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    description.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Cash entry saved successfully.'
                : 'Cash entry updated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _showEntryActions(CashbookEntryModel entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (entry.receiptUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('View Receipt'),
                onTap: () => Navigator.pop(context, 'receipt'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Entry'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _red),
              title: const Text('Delete Entry', style: TextStyle(color: _red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await context.push('${AppRoutes.editCashEntry}/${entry.id}');
    } else if (action == 'receipt') {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.network(entry.receiptUrl)),
        ),
      );
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete cash entry?'),
          content: const Text(
            'This will reverse its effect on the business cash balance.',
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
            .read(cashbookMutationProvider.notifier)
            .delete(entry);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleted
                    ? 'Cash entry deleted and balance updated.'
                    : 'Could not delete this cash entry.',
              ),
            ),
          );
        }
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.businessName,
    required this.userName,
    required this.photoUrl,
  });
  final String businessName;
  final String userName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFE6ECFF),
        backgroundImage: photoUrl == null || photoUrl!.isEmpty
            ? null
            : NetworkImage(photoUrl!),
        child: photoUrl == null || photoUrl!.isEmpty
            ? const Icon(Icons.person_outline, size: 19, color: _blue)
            : null,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              businessName,
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(userName, style: const TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => context.push(AppRoutes.notifications),
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: _blue,
          size: 20,
        ),
      ),
    ],
  );
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFCFD9F6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: _blue, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _blue,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Icon(Icons.expand_more_rounded, color: _blue, size: 18),
        ],
      ),
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.color,
    this.icon,
  });
  final String label;
  final double amount;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 83,
    padding: const EdgeInsets.all(11),
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
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Text(label, style: const TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
        const Spacer(),
        Text(
          _money(amount),
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onSelected});
  final _CashPeriod value;
  final ValueChanged<_CashPeriod> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF1F7),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: _CashPeriod.values.map((period) {
        final selected = period == value;
        return Expanded(
          child: InkWell(
            onTap: () => onSelected(period),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _blue : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                switch (period) {
                  _CashPeriod.today => 'Today',
                  _CashPeriod.weekly => 'Weekly',
                  _CashPeriod.monthly => 'Monthly',
                  _CashPeriod.custom => 'Custom',
                },
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.entries,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTap,
  });
  final List<CashbookEntryModel> entries;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final ValueChanged<CashbookEntryModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && entries.isEmpty) {
      return Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF3),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      );
    }
    if (error && entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Could not load cash entries.'),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text(
          'No cash entries for this period',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final item = entries[index];
          final cashIn = item.isCashIn;
          final title = item.description.trim().isNotEmpty
              ? item.description.trim()
              : item.category;
          return Column(
            children: [
              ListTile(
                onTap: () => onTap(item),
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                leading: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: (cashIn ? _green : _red).withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    cashIn
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: cashIn ? _green : _red,
                    size: 18,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${item.category} • ${item.paymentMethod} • '
                  '${DateFormat('dd MMM, hh:mm a').format(item.entryDate)}',
                  style: const TextStyle(fontSize: 7, color: _muted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.receiptUrl.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: _blue,
                          size: 14,
                        ),
                      ),
                    Text(
                      '${cashIn ? '+' : '-'} ${_money(item.amount)}',
                      style: TextStyle(
                        color: cashIn ? _green : _red,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (index != entries.length - 1)
                const Divider(height: 1, indent: 54, color: Color(0xFFE8EBF2)),
            ],
          );
        }),
      ),
    );
  }
}

String _money(double amount) =>
    NumberFormat.currency(symbol: '₨ ', decimalDigits: 2).format(amount);
