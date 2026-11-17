import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes/app_routes.dart';
import '../../models/customer_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/edit_customer_provider.dart';
import '../../providers/transaction_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _red = Color(0xFFD71920);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _page = Color(0xFFF8F9FD);

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});
  final String customerId;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPhone(CustomerModel customer) async {
    final phone = customer.phone.replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return;
    await launchUrl(
      Uri.parse('tel:${phone.startsWith('+') ? phone : '+92$phone'}'),
    );
  }

  Future<void> _openWhatsApp(CustomerModel customer) async {
    var phone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('92')) phone = '92$phone';
    await launchUrl(
      Uri.parse('https://wa.me/$phone'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _sendReminder(CustomerModel customer) async {
    var phone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('92')) phone = '92$phone';
    final balance = _money(customer.currentBalance.abs());
    final message = customer.currentBalance > 0
        ? 'Hello ${customer.name}, this is a reminder that $balance is pending on your Smart Khata account.'
        : 'Hello ${customer.name}, your Smart Khata balance is $balance.';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  void _openTransaction(String type, CustomerModel customer) {
    context.push(
      '${AppRoutes.addTransaction}?customerId=${customer.id}&type=$type',
    );
  }

  Future<Uint8List> _statementPdf(
    CustomerModel customer,
    List<TransactionModel> transactions,
  ) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Smart Khata - Customer Statement',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Customer: ${customer.name}'),
          pw.Text('Phone: ${customer.phone}'),
          pw.Text('Account: ${customer.accountType}'),
          pw.Text('Current balance: ${_money(customer.currentBalance)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Type',
              'Description',
              'Amount',
              'Previous',
              'New',
            ],
            data: transactions
                .map(
                  (item) => [
                    DateFormat('dd MMM yyyy').format(item.transactionDate),
                    item.transactionType == 'gave'
                        ? 'You Gave'
                        : 'You Received',
                    item.description,
                    item.amount.toStringAsFixed(2),
                    item.previousBalance.toStringAsFixed(2),
                    item.updatedBalance.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> _showStatementActions(
    CustomerModel customer,
    List<TransactionModel> transactions,
  ) async {
    final now = DateTime.now();
    final start = _dateRange?.start ?? DateTime(now.year, now.month, 1);
    final end = _dateRange?.end ?? now;
    if (customer.id.isNotEmpty) {
      await context.push(
        '${AppRoutes.statementPreview}?customerId=${Uri.encodeQueryComponent(customer.id)}'
        '&startDate=${Uri.encodeQueryComponent(start.toIso8601String())}'
        '&endDate=${Uri.encodeQueryComponent(end.toIso8601String())}',
      );
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download Statement'),
              onTap: () => Navigator.pop(context, 'download'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Statement'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      final bytes = await _statementPdf(customer, transactions);
      final fileName =
          '${customer.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_statement.pdf';
      if (action == 'share') {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the statement.')),
        );
      }
    }
  }

  Future<void> _showFilters() async {
    var selectedType = _filter;
    var selectedRange = _dateRange;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Filter Transactions',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'gave', label: Text('Gave')),
                    ButtonSegment(value: 'received', label: Text('Received')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (value) =>
                      setSheetState(() => selectedType = value.first),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    selectedRange == null
                        ? 'Select date range'
                        : '${DateFormat('dd MMM').format(selectedRange!.start)} - '
                              '${DateFormat('dd MMM').format(selectedRange!.end)}',
                  ),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: selectedRange,
                    );
                    if (range != null) {
                      setSheetState(() => selectedRange = range);
                    }
                  },
                ),
                if (selectedRange != null)
                  TextButton(
                    onPressed: () => setSheetState(() => selectedRange = null),
                    child: const Text('Clear date range'),
                  ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _filter = selectedType;
                      _dateRange = selectedRange;
                    });
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTransactionDetails(TransactionModel transaction) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            runSpacing: 8,
            children: [
              Text(
                transaction.transactionType == 'gave'
                    ? 'You Gave'
                    : 'You Received',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_money(transaction.amount)),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy, hh:mm a').format(transaction.transactionDate)}\n'
                  '${transaction.description.isEmpty ? 'No description' : transaction.description}\n'
                  'Previous: ${_money(transaction.previousBalance)}  '
                  'New: ${_money(transaction.updatedBalance)}',
                ),
              ),
              if (transaction.receiptUrl.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('View receipt'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showReceipt(transaction.receiptUrl);
                  },
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(
                          '${AppRoutes.editTransaction}/${transaction.id}',
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _deleteTransaction(transaction);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReceipt(String url) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: InteractiveViewer(
        child: Image.network(
          url,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Could not load this receipt.'),
          ),
        ),
      ),
    ),
  );

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'The transaction effect will be reversed and balances recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ref
        .read(ledgerMutationProvider.notifier)
        .delete(transaction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Transaction deleted and balances updated.'
              : ref.read(ledgerMutationProvider).errorMessage ??
                    'Could not delete transaction.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    return customerAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (error, _) => _CustomerLoadState(
        message: error.toString().contains('permission')
            ? 'You do not have permission to view this customer.'
            : 'Could not load customer details.',
        onRetry: () => ref.invalidate(customerByIdProvider(widget.customerId)),
      ),
      data: (customer) => customer == null
          ? _CustomerLoadState(
              message: 'Customer not found.',
              onRetry: () =>
                  ref.invalidate(customerByIdProvider(widget.customerId)),
            )
          : _buildDetails(customer),
    );
  }

  Widget _buildDetails(CustomerModel customer) {
    final transactionsAsync = ref.watch(
      customerTransactionsProvider(customer.id),
    );
    final transactions = transactionsAsync.value ?? const <TransactionModel>[];
    final visible = transactions.where((item) {
      final matchesFilter =
          _filter == 'all' ||
          (_filter == 'gave' && item.transactionType == 'gave') ||
          (_filter == 'received' && item.transactionType != 'gave');
      final endDate = _dateRange == null
          ? null
          : DateTime(
              _dateRange!.end.year,
              _dateRange!.end.month,
              _dateRange!.end.day,
              23,
              59,
              59,
            );
      final matchesDate =
          _dateRange == null ||
          (!item.transactionDate.isBefore(_dateRange!.start) &&
              !item.transactionDate.isAfter(endDate!));
      final matchesSearch =
          _query.isEmpty ||
          item.description.toLowerCase().contains(_query) ||
          item.amount.toString().contains(_query) ||
          DateFormat(
            'dd MMM yyyy',
          ).format(item.transactionDate).toLowerCase().contains(_query);
      return matchesFilter && matchesSearch && matchesDate;
    }).toList();

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
          'Customer Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showStatementActions(customer, transactions),
            icon: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 19,
            ),
          ),
          IconButton(
            onPressed: () =>
                context.push('${AppRoutes.editCustomer}/${customer.id}'),
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: 19,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(customerByIdProvider(customer.id));
                ref.invalidate(customerTransactionsProvider(customer.id));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 95),
                children: [
                  _CustomerCard(customer: customer),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.call_outlined,
                          label: 'Call',
                          onTap: () => _openPhone(customer),
                        ),
                      ),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.chat_outlined,
                          label: 'WhatsApp',
                          onTap: () => _openWhatsApp(customer),
                        ),
                      ),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () => context.push(
                            '${AppRoutes.editCustomer}/${customer.id}',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.alarm_outlined,
                          label: 'Reminder',
                          onTap: () => _sendReminder(customer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search transactions...',
                            hintStyle: const TextStyle(
                              color: _muted,
                              fontSize: 9,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _muted,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: _border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      InkWell(
                        onTap: _showFilters,
                        child: Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(
                            Icons.filter_alt_outlined,
                            color: _blue,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Transactions',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'Showing ${visible.length}',
                        style: const TextStyle(color: _muted, fontSize: 8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _LedgerList(
                    transactions: visible,
                    loading: transactionsAsync.isLoading,
                    error: transactionsAsync.hasError,
                    onRetry: () => ref.invalidate(
                      customerTransactionsProvider(customer.id),
                    ),
                    onTap: _showTransactionDetails,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
          child: Row(
            children: [
              Expanded(
                child: _BottomAction(
                  label: 'You Gave',
                  icon: Icons.north_east_rounded,
                  color: _red,
                  onTap: () => _openTransaction('gave', customer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BottomAction(
                  label: 'You Received',
                  icon: Icons.south_west_rounded,
                  color: _green,
                  onTap: () => _openTransaction('received', customer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final balance = customer.currentBalance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFE8EEFF),
            backgroundImage: customer.profileImage.isEmpty
                ? null
                : NetworkImage(customer.profileImage),
            child: customer.profileImage.isEmpty
                ? Text(
                    _initials(customer.name),
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.phone.isEmpty
                      ? customer.accountType
                      : '${customer.phone} • ${customer.accountType}',
                  style: const TextStyle(color: _muted, fontSize: 8),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'CURRENT\nBALANCE',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _muted,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _money(balance.abs()),
                style: TextStyle(
                  color: balance >= 0 ? _red : _green,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: balance >= 0 ? _red : _green,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  balance > 0
                      ? 'You’ll Get'
                      : balance < 0
                      ? 'You’ll Pay'
                      : 'Settled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: _blue, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 8, color: _ink)),
        ],
      ),
    ),
  );
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({
    required this.transactions,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTap,
  });
  final List<TransactionModel> transactions;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final ValueChanged<TransactionModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(25),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error && transactions.isEmpty) {
      return Column(
        children: [
          const Text(
            'Could not load transactions.',
            style: TextStyle(color: _muted),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _border),
        ),
        child: const Text(
          'No transactions found',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 10),
        ),
      );
    }
    String? previousDate;
    final widgets = <Widget>[];
    for (final item in transactions) {
      final date = DateFormat('dd MMMM yyyy').format(item.transactionDate);
      if (date != previousDate) {
        widgets.add(_MonthDivider(date));
        previousDate = date;
      }
      widgets.add(_LedgerTile(transaction: item, onTap: () => onTap(item)));
      widgets.add(const SizedBox(height: 8));
    }
    return Column(children: widgets);
  }
}

class _MonthDivider extends StatelessWidget {
  const _MonthDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Expanded(child: Divider(color: _border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(color: _blue, fontSize: 8)),
        ),
        const Expanded(child: Divider(color: _border)),
      ],
    ),
  );
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.transaction, required this.onTap});
  final TransactionModel transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final received = transaction.transactionType != 'gave';
    final color = received ? _green : _red;
    final label = received ? 'Received (Payment)' : 'Gave (Credit)';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                received ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.trim().isEmpty
                        ? label
                        : transaction.description.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Previous: ${_money(transaction.previousBalance.abs())}',
                    style: const TextStyle(color: _muted, fontSize: 7),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat(
                      'dd MMM, yyyy • hh:mm a',
                    ).format(transaction.transactionDate),
                    style: const TextStyle(color: _muted, fontSize: 7),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${received ? '+' : '-'} ${_money(transaction.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bal: ${_money(transaction.updatedBalance.abs())}',
                  style: const TextStyle(color: _muted, fontSize: 7),
                ),
                if (transaction.receiptUrl.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: _blue,
                      size: 13,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
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
    height: 48,
    child: FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

String _money(double amount) =>
    NumberFormat.currency(symbol: '₨ ', decimalDigits: 2).format(amount);

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'C';
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}

class _CustomerLoadState extends StatelessWidget {
  const _CustomerLoadState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    appBar: AppBar(
      leading: IconButton(
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Customer Details'),
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 50, color: _muted),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
