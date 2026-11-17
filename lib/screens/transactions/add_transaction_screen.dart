import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/routes/app_routes.dart';
import '../../models/customer_model.dart';
import '../../providers/add_transaction_provider.dart';
import '../../providers/customer_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _field = Color(0xFFF7F8FC);
const _page = Color(0xFFF8F9FD);

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.customerId,
    this.initialType = 'gave',
  });
  final String? customerId;
  final String initialType;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  late String _type;
  CustomerModel? _customer;
  DateTime _date = DateTime.now();
  String _paymentMethod = 'Cash';
  File? _receipt;
  bool _setReminder = false;
  DateTime? _reminderDate;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'received' ? 'received' : 'gave';
    _amountController.addListener(_refreshBalance);
  }

  void _refreshBalance() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_refreshBalance)
      ..dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (selectedTime != null && mounted) {
      setState(
        () => _date = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        ),
      );
    }
  }

  Future<void> _pickReminderDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null && mounted) setState(() => _reminderDate = selected);
  }

  Future<void> _pickReceipt() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1400,
    );
    if (selected != null && mounted) {
      setState(() => _receipt = File(selected.path));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        ref.read(addTransactionProvider).isLoading) {
      return;
    }
    final customer = _customer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer.')),
      );
      return;
    }
    if (_setReminder && _reminderDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a reminder date.')));
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(addTransactionProvider.notifier)
        .create(
          AddTransactionInput(
            customer: customer,
            type: _type,
            amount: double.parse(_amountController.text.trim()),
            date: _date,
            description: _notesController.text,
            paymentMethod: _paymentMethod,
            receipt: _receipt,
            reminderDate: _setReminder ? _reminderDate : null,
          ),
        );
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _projectedBalance =>
      (_customer?.currentBalance ?? 0) + (_type == 'gave' ? _amount : -_amount);

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? <CustomerModel>[];
    if (widget.customerId != null) {
      _customer =
          customers.where((item) => item.id == widget.customerId).firstOrNull ??
          _customer;
    } else if (_customer != null) {
      _customer =
          customers.where((item) => item.id == _customer!.id).firstOrNull ??
          _customer;
    }
    ref.listen(addTransactionProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == AddTransactionStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Could not save.')),
        );
      } else if (next.status == AddTransactionStatus.success &&
          next.transaction != null) {
        final transaction = next.transaction!;
        ref.read(addTransactionProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully.')),
        );
        if (widget.customerId != null) {
          context.pop(transaction);
        } else {
          context.pushReplacement(
            '${AppRoutes.customerDetails}/${transaction.customerId}',
          );
        }
      }
    });
    final submitState = ref.watch(addTransactionProvider);
    final loading = submitState.isLoading;

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
          'Add Transaction',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Transaction balance'),
                content: const Text(
                  'You Gave increases the amount the customer owes you. '
                  'You Received reduces that balance.',
                ),
                actions: [
                  TextButton(
                    onPressed: context.pop,
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 105),
          children: [
            _TransactionTabs(
              type: _type,
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 13),
            if (widget.customerId == null) ...[
              const _FieldLabel('Customer / Supplier *'),
              DropdownButtonFormField<CustomerModel>(
                initialValue: _customer,
                isExpanded: true,
                decoration: _inputDecoration('Select customer'),
                items: customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer,
                        child: Text(
                          customer.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'Select a customer.' : null,
                onChanged: (value) => setState(() => _customer = value),
              ),
              const SizedBox(height: 13),
            ],
            if (_customer != null) ...[
              _FieldLabel(
                '${_customer!.name} • Current ${_money(_customer!.currentBalance.abs())}',
              ),
              const SizedBox(height: 4),
            ],
            _BalancePreview(
              currentBalance: _customer?.currentBalance ?? 0,
              projectedBalance: _projectedBalance,
              type: _type,
            ),
            const SizedBox(height: 15),
            const _FieldLabel('Amount *'),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: _blue,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              decoration: _inputDecoration('0.00').copyWith(
                prefixText: '₨  ',
                prefixStyle: const TextStyle(
                  color: _blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a positive amount.'
                    : null;
              },
            ),
            const SizedBox(height: 13),
            const _FieldLabel('Transaction Date'),
            InkWell(
              onTap: _pickDate,
              child: IgnorePointer(
                child: TextFormField(
                  key: ValueKey(_date),
                  initialValue: DateFormat(
                    'dd/MM/yyyy • hh:mm a',
                  ).format(_date),
                  decoration: _inputDecoration('').copyWith(
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            const _FieldLabel('Payment Method'),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: _inputDecoration('Payment Method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(
                  value: 'Bank Transfer',
                  child: Text('Bank Transfer'),
                ),
                DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'Easypaisa', child: Text('Easypaisa')),
                DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) =>
                  setState(() => _paymentMethod = value ?? 'Cash'),
            ),
            const SizedBox(height: 13),
            const _FieldLabel('Description / Notes'),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 10),
              decoration: _inputDecoration(
                'What was this for? (e.g. Monthly rent, Raw materials)',
              ),
            ),
            const SizedBox(height: 13),
            const _FieldLabel('Attach Receipt (Optional)'),
            InkWell(
              onTap: _pickReceipt,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF9EB4E7)),
                ),
                child: _receipt == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_outlined,
                            color: _blue,
                            size: 27,
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Tap to upload image',
                            style: TextStyle(color: _blue, fontSize: 9),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Max size: 5MB',
                            style: TextStyle(color: _muted, fontSize: 8),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(_receipt!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 13),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Set Reminder',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              value: _setReminder,
              onChanged: loading
                  ? null
                  : (value) => setState(() {
                      _setReminder = value;
                      if (!value) _reminderDate = null;
                    }),
            ),
            if (_setReminder) ...[
              const _FieldLabel('Reminder Date *'),
              InkWell(
                onTap: _pickReminderDate,
                child: IgnorePointer(
                  child: TextFormField(
                    key: ValueKey(_reminderDate),
                    initialValue: _reminderDate == null
                        ? ''
                        : DateFormat('dd/MM/yyyy').format(_reminderDate!),
                    decoration: _inputDecoration('Select reminder date'),
                    validator: (_) => _reminderDate == null
                        ? 'Select a reminder date.'
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 49,
                  child: OutlinedButton(
                    onPressed: loading ? null : context.pop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 49,
                  child: FilledButton(
                    onPressed: loading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
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
                                submitState.status ==
                                        AddTransactionStatus.uploading
                                    ? 'Uploading ${(submitState.uploadProgress * 100).round()}%'
                                    : 'Saving...',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          )
                        : const Text(
                            'Save Transaction',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTabs extends StatelessWidget {
  const _TransactionTabs({required this.type, required this.onChanged});
  final String type;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _TabButton(
          label: 'You Gave',
          selected: type == 'gave',
          onTap: () => onChanged('gave'),
        ),
      ),
      Expanded(
        child: _TabButton(
          label: 'You Received',
          selected: type == 'received',
          onTap: () => onChanged('received'),
        ),
      ),
    ],
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? _blue : _border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _blue : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _BalancePreview extends StatelessWidget {
  const _BalancePreview({
    required this.currentBalance,
    required this.projectedBalance,
    required this.type,
  });
  final double currentBalance;
  final double projectedBalance;
  final String type;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current Ledger Balance',
                style: TextStyle(color: _muted, fontSize: 8),
              ),
            ),
            Text(
              type == 'gave' ? 'Transaction (Out)' : 'Transaction (In)',
              style: const TextStyle(color: _muted, fontSize: 8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _money(currentBalance.abs()),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${type == 'gave' ? '+' : '-'} ${_money((projectedBalance - currentBalance).abs())}',
              style: TextStyle(
                color: type == 'gave' ? _redColor : _green,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Divider(height: 20, color: _border),
        Row(
          children: [
            const Expanded(
              child: Text(
                'New Balance',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              _money(projectedBalance.abs()),
              style: const TextStyle(
                color: _blue,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _muted, fontSize: 9),
  filled: true,
  fillColor: _field,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: _border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: _border),
  ),
);

const _redColor = Color(0xFFD71920);

String _money(double amount) =>
    NumberFormat.currency(symbol: '₨ ', decimalDigits: 2).format(amount);
