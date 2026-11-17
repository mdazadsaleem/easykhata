import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';
import '../../providers/edit_customer_provider.dart';
import '../../providers/edit_transaction_provider.dart';

const _blue = Color(0xFF123EAD);
const _red = Color(0xFFD71920);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _field = Color(0xFFF7F8FC);
const _page = Color(0xFFF8F9FD);

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({required this.transactionId, super.key});
  final String transactionId;

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  TransactionModel? _original;
  String _type = 'gave';
  String _paymentMethod = 'Cash';
  DateTime _date = DateTime.now();
  File? _newReceipt;
  bool _prefilled = false;

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

  void _prefill(TransactionModel transaction) {
    if (_prefilled) return;
    _prefilled = true;
    _original = transaction;
    _amount.text = transaction.amount.toStringAsFixed(2);
    _description.text = transaction.description;
    _type = transaction.transactionType;
    _date = transaction.transactionDate;
    _paymentMethod = _paymentMethods.contains(transaction.paymentMethod)
        ? transaction.paymentMethod
        : 'Other';
  }

  double get _editedAmount => double.tryParse(_amount.text.trim()) ?? 0;
  double get _oldEffect {
    final transaction = _original;
    if (transaction == null) return 0;
    return transaction.transactionType == 'gave'
        ? transaction.amount
        : -transaction.amount;
  }

  double get _newEffect => _type == 'gave' ? _editedAmount : -_editedAmount;
  double get _preview =>
      (_original?.updatedBalance ?? 0) - _oldEffect + _newEffect;

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

  Future<void> _confirmUpdate() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        ref.read(editTransactionProvider).isLoading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update transaction?'),
        content: const Text(
          'The old balance effect will be reversed before applying these changes.',
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
    final original = _original;
    if (confirmed != true || original == null) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(editTransactionProvider.notifier)
        .update(
          original: original,
          type: _type,
          amount: _editedAmount,
          date: _date,
          description: _description.text,
          paymentMethod: _paymentMethod,
          newReceipt: _newReceipt,
        );
  }

  Future<void> _confirmDelete() async {
    final original = _original;
    if (original == null || ref.read(editTransactionProvider).isLoading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will reverse the transaction effect and update the customer balance.',
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
      await ref.read(editTransactionProvider.notifier).delete(original);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editTransactionProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == EditTransactionStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Something went wrong.')),
        );
      } else if (next.status == EditTransactionStatus.success &&
          next.transaction != null) {
        final updated = next.transaction!;
        ref.read(editTransactionProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully.')),
        );
        context.pop(updated);
      } else if (next.status == EditTransactionStatus.deleted) {
        final deleted = next.transaction;
        ref.read(editTransactionProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully.')),
        );
        context.pop(deleted);
      }
    });
    final transactionAsync = ref.watch(
      transactionByIdProvider(widget.transactionId),
    );
    return transactionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (error, _) => _LoadError(
        message: error.toString().replaceFirst('Bad state: ', ''),
        onRetry: () =>
            ref.invalidate(transactionByIdProvider(widget.transactionId)),
      ),
      data: (transaction) {
        if (transaction == null) {
          return _LoadError(
            message: 'Transaction not found.',
            onRetry: () =>
                ref.invalidate(transactionByIdProvider(widget.transactionId)),
          );
        }
        final customerAsync = ref.watch(
          customerByIdProvider(transaction.customerId),
        );
        if (customerAsync.isLoading) {
          return const Scaffold(
            backgroundColor: _page,
            body: Center(child: CircularProgressIndicator(color: _blue)),
          );
        }
        if (customerAsync.hasError) {
          return _LoadError(
            message: 'Could not verify the transaction customer.',
            onRetry: () =>
                ref.invalidate(customerByIdProvider(transaction.customerId)),
          );
        }
        if (customerAsync.value == null) {
          return _LoadError(
            message: 'The customer for this transaction no longer exists.',
            onRetry: () =>
                ref.invalidate(customerByIdProvider(transaction.customerId)),
          );
        }
        _prefill(transaction);
        return _form(transaction);
      },
    );
  }

  Widget _form(TransactionModel transaction) {
    final action = ref.watch(editTransactionProvider);
    final loading = action.isLoading;
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
          'Edit Transaction',
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 115),
          children: [
            Row(
              children: [
                Expanded(child: _typeButton('You Gave', 'gave')),
                Expanded(child: _typeButton('You Received', 'received')),
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
                  _balanceRow(
                    'Old balance effect',
                    '${_oldEffect >= 0 ? '+' : '-'} ${_money(_oldEffect.abs())}',
                  ),
                  const Divider(height: 20),
                  _balanceRow('New balance preview', _money(_preview.abs())),
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
            _label('Transaction Date'),
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
                    (method) =>
                        DropdownMenuItem(value: method, child: Text(method)),
                  )
                  .toList(),
              onChanged: loading
                  ? null
                  : (value) => setState(() => _paymentMethod = value ?? 'Cash'),
            ),
            const SizedBox(height: 13),
            _label('Description / Notes'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: _decoration('Transaction description'),
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
                    : transaction.receiptUrl.isNotEmpty
                    ? Image.network(
                        transaction.receiptUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.upload_file_outlined,
                          color: _blue,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_outlined, color: _blue),
                          SizedBox(height: 6),
                          Text(
                            'Tap to replace receipt',
                            style: TextStyle(fontSize: 9, color: _blue),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: loading ? null : _confirmDelete,
              style: OutlinedButton.styleFrom(foregroundColor: _red),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Transaction'),
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
              onPressed: loading ? null : _confirmUpdate,
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
                          action.status == EditTransactionStatus.uploading
                              ? 'Uploading ${(action.progress * 100).round()}%'
                              : action.status == EditTransactionStatus.deleting
                              ? 'Deleting...'
                              : 'Updating...',
                        ),
                      ],
                    )
                  : const Text('Update Transaction'),
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

  Widget _balanceRow(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
      ),
      Text(
        value,
        style: const TextStyle(
          color: _blue,
          fontSize: 15,
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
      title: const Text('Edit Transaction'),
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
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
