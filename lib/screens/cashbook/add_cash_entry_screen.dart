import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/add_cash_entry_provider.dart';
import '../../providers/business_providers.dart';
import '../../providers/main_navigation_providers.dart';

const _blue = Color(0xFF173EB5);
const _green = Color(0xFF009E60);
const _red = Color(0xFFD92D3A);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _field = Color(0xFFF7F8FC);
const _page = Color(0xFFF8F9FD);

class AddCashEntryScreen extends ConsumerStatefulWidget {
  const AddCashEntryScreen({this.initialType = 'cashIn', super.key});
  final String initialType;

  @override
  ConsumerState<AddCashEntryScreen> createState() => _AddCashEntryScreenState();
}

class _AddCashEntryScreenState extends ConsumerState<AddCashEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  late String _type;
  String? _category;
  String _paymentMethod = 'Cash';
  DateTime _date = DateTime.now();
  File? _receipt;

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
    _type = widget.initialType == 'cashOut' ? 'cashOut' : 'cashIn';
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
      setState(() => _receipt = File(selected.path));
    }
  }

  Future<void> _save(double currentBalance) async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        ref.read(addCashEntryProvider).isLoading) {
      return;
    }
    if (_type == 'cashOut' && _value > currentBalance) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient cash balance'),
          content: Text(
            'This Cash Out is ${_money(_value - currentBalance)} more than '
            'the current cash balance. Save it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(addCashEntryProvider.notifier)
        .create(
          AddCashEntryInput(
            type: _type,
            amount: _value,
            category: _category!,
            date: _date,
            description: _description.text,
            paymentMethod: _paymentMethod,
            receipt: _receipt,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(addCashEntryProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == AddCashEntryStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Could not save entry.')),
        );
      } else if (next.status == AddCashEntryStatus.success &&
          next.entry != null) {
        final entry = next.entry!;
        ref.read(addCashEntryProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash entry saved successfully.')),
        );
        ref.read(mainNavigationIndexProvider.notifier).select(2);
        context.pop(entry);
      }
    });
    final business = ref.watch(currentBusinessProvider).value;
    final currentBalance = business?.cashBalance ?? 0;
    final newBalance = currentBalance + (_type == 'cashIn' ? _value : -_value);
    final action = ref.watch(addCashEntryProvider);
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
          'Add Cash Entry',
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
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
                  _balanceRow('New Cash Balance', newBalance),
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
                final parsed = double.tryParse(value ?? '');
                return parsed == null || parsed <= 0
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
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
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
                    (method) =>
                        DropdownMenuItem(value: method, child: Text(method)),
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
            _label('Receipt Image (Optional)'),
            InkWell(
              onTap: loading ? null : _pickReceipt,
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
                          Icon(Icons.upload_file_outlined, color: _blue),
                          SizedBox(height: 6),
                          Text(
                            'Tap to upload receipt',
                            style: TextStyle(color: _blue, fontSize: 9),
                          ),
                        ],
                      )
                    : Image.file(_receipt!, fit: BoxFit.cover),
              ),
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
              onPressed: loading ? null : () => _save(currentBalance),
              style: FilledButton.styleFrom(
                backgroundColor: _type == 'cashIn' ? _green : _red,
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
                          action.status == AddCashEntryStatus.uploading
                              ? 'Uploading ${(action.progress * 100).round()}%'
                              : 'Saving...',
                        ),
                      ],
                    )
                  : const Text('Save Cash Entry'),
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
