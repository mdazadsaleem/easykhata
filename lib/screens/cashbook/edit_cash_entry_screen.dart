import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/cashbook_entry_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/edit_cash_entry_provider.dart';

const _blue = Color(0xFF173EB5);
const _red = Color(0xFFD92D3A);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _field = Color(0xFFF7F8FC);
const _page = Color(0xFFF8F9FD);

class EditCashEntryScreen extends ConsumerStatefulWidget {
  const EditCashEntryScreen({required this.entryId, super.key});
  final String entryId;

  @override
  ConsumerState<EditCashEntryScreen> createState() =>
      _EditCashEntryScreenState();
}

class _EditCashEntryScreenState extends ConsumerState<EditCashEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  CashbookEntryModel? _original;
  String _type = 'cashIn';
  String? _category;
  String _paymentMethod = 'Cash';
  DateTime _date = DateTime.now();
  File? _newReceipt;
  bool _prefilled = false;

  static const _categories = [
    'Sales',
    'Purchase',
    'Rent',
    'Salary',
    'Utilities',
    'Transport',
    'Food',
    'Maintenance',
    'Investment',
    'Withdrawal',
    'Other',
  ];
  static const _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Easypaisa',
    'JazzCash',
    'Card',
    'Cheque',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _amount.addListener(_refresh);
  }

  @override
  void dispose() {
    _amount
      ..removeListener(_refresh)
      ..dispose();
    _description.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _prefill(CashbookEntryModel entry) {
    if (_prefilled) return;
    _prefilled = true;
    _original = entry;
    _type = entry.type;
    _amount.text = entry.amount.toStringAsFixed(2);
    _category = _categories.contains(entry.category) ? entry.category : 'Other';
    _description.text = entry.description;
    _paymentMethod = _paymentMethods.contains(entry.paymentMethod)
        ? entry.paymentMethod
        : 'Other';
    _date = entry.entryDate;
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _pickReceipt() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1400,
    );
    if (selected != null && mounted) {
      setState(() => _newReceipt = File(selected.path));
    }
  }

  Future<void> _update() async {
    final original = _original;
    if (original == null ||
        !(_formKey.currentState?.validate() ?? false) ||
        ref.read(editCashEntryProvider).isLoading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update cash entry?'),
        content: const Text(
          'The old cash effect will be reversed before applying these changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(editCashEntryProvider.notifier)
        .update(
          original: original,
          type: _type,
          amount: _value,
          category: _category!,
          date: _date,
          description: _description.text,
          paymentMethod: _paymentMethod,
          newReceipt: _newReceipt,
        );
  }

  Future<void> _delete() async {
    final original = _original;
    if (original == null || ref.read(editCashEntryProvider).isLoading) return;
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
      await ref.read(editCashEntryProvider.notifier).delete(original);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editCashEntryProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == EditCashEntryStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Something went wrong.')),
        );
      } else if (next.status == EditCashEntryStatus.success &&
          next.entry != null) {
        final entry = next.entry!;
        ref.read(editCashEntryProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash entry updated successfully.')),
        );
        context.pop(entry);
      } else if (next.status == EditCashEntryStatus.deleted) {
        final entry = next.entry;
        ref.read(editCashEntryProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash entry deleted successfully.')),
        );
        context.pop(entry);
      }
    });
    final entryAsync = ref.watch(cashbookEntryByIdProvider(widget.entryId));
    return entryAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (error, _) => _LoadError(
        message: error.toString().replaceFirst('Bad state: ', ''),
        onRetry: () =>
            ref.invalidate(cashbookEntryByIdProvider(widget.entryId)),
      ),
      data: (entry) {
        if (entry == null) {
          return _LoadError(
            message: 'Cashbook entry not found.',
            onRetry: () =>
                ref.invalidate(cashbookEntryByIdProvider(widget.entryId)),
          );
        }
        _prefill(entry);
        return _form(entry);
      },
    );
  }

  Widget _form(CashbookEntryModel entry) {
    final action = ref.watch(editCashEntryProvider);
    final loading = action.isLoading;
    final currentBalance =
        ref.watch(currentBusinessProvider).value?.cashBalance ?? 0;
    final oldEffect = entry.isCashIn ? entry.amount : -entry.amount;
    final newEffect = _type == 'cashIn' ? _value : -_value;
    final preview = currentBalance - oldEffect + newEffect;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: loading ? null : context.pop,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text(
          'Edit Cash Entry',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
          children: [
            Row(
              children: [
                Expanded(child: _typeButton('Cash In', 'cashIn')),
                Expanded(child: _typeButton('Cash Out', 'cashOut')),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  _balanceRow('Current Cash Balance', currentBalance),
                  const Divider(height: 20),
                  _balanceRow('Updated Balance Preview', preview),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _label('Amount *'),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration('0.00').copyWith(prefixText: '₨  '),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a positive amount.'
                    : null;
              },
            ),
            const SizedBox(height: 13),
            _label('Category *'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _decoration('Select category'),
              items: _categories
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              validator: (value) => value == null ? 'Select a category.' : null,
              onChanged: loading
                  ? null
                  : (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 13),
            _label('Date and Time'),
            InkWell(
              onTap: loading ? null : _pickDateTime,
              child: IgnorePointer(
                child: TextFormField(
                  key: ValueKey(_date),
                  initialValue: DateFormat(
                    'dd/MM/yyyy • hh:mm a',
                  ).format(_date),
                  decoration: _decoration('').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            _label('Payment Method'),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: _decoration('Payment Method'),
              items: _paymentMethods
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: loading
                  ? null
                  : (value) => setState(() => _paymentMethod = value ?? 'Cash'),
            ),
            const SizedBox(height: 13),
            _label('Description'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: _decoration('Enter description or notes'),
            ),
            const SizedBox(height: 13),
            _label('Receipt Image'),
            InkWell(
              onTap: loading ? null : _pickReceipt,
              child: Container(
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF9EB4E7)),
                ),
                child: _newReceipt != null
                    ? Image.file(_newReceipt!, fit: BoxFit.cover)
                    : entry.receiptUrl.isNotEmpty
                    ? Image.network(
                        entry.receiptUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.upload_file_outlined,
                          color: _blue,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined, color: _blue),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: loading ? null : _delete,
              style: OutlinedButton.styleFrom(foregroundColor: _red),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Entry'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: SizedBox(
            height: 49,
            child: FilledButton(
              onPressed: loading ? null : _update,
              style: FilledButton.styleFrom(backgroundColor: _blue),
              child: loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          action.status == EditCashEntryStatus.uploading
                              ? 'Uploading ${(action.progress * 100).round()}%'
                              : action.status == EditCashEntryStatus.deleting
                              ? 'Deleting...'
                              : 'Updating...',
                        ),
                      ],
                    )
                  : const Text('Update Entry'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String label, String value) => InkWell(
    onTap: () => setState(() => _type = value),
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _type == value ? _blue : _border,
            width: _type == value ? 2 : 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _type == value ? _blue : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _balanceRow(String label, double amount) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
      ),
      Text(
        _money(amount),
        style: TextStyle(
          color: amount < 0 ? _red : _blue,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Edit Cash Entry'),
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.money_off_rounded, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Widget _label(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    value,
    style: const TextStyle(
      color: _ink,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    ),
  ),
);

InputDecoration _decoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: _field,
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: _border),
  ),
);

String _money(double amount) =>
    NumberFormat.currency(symbol: '₨ ', decimalDigits: 2).format(amount);
