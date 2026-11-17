import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/validators.dart';
import '../../models/customer_model.dart';
import '../../providers/edit_customer_provider.dart';
import '../../providers/app_providers.dart';

const _blue = Color(0xFF123EAD);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD9DEEA);
const _field = Color(0xFFF4F6FC);
const _page = Color(0xFFF8F9FD);

class EditCustomerScreen extends ConsumerStatefulWidget {
  const EditCustomerScreen({required this.customerId, super.key});
  final String customerId;

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _picker = ImagePicker();
  CustomerModel? _customer;
  File? _newImage;
  String _accountType = 'customer';
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _prefill(CustomerModel customer) {
    if (_prefilled) return;
    _prefilled = true;
    _customer = customer;
    _name.text = customer.name;
    _phone.text = customer.phone.startsWith('+92')
        ? customer.phone.substring(3)
        : customer.phone;
    _address.text = customer.address;
    _notes.text = customer.notes;
    _accountType = customer.accountType;
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 900,
    );
    if (image != null && mounted) setState(() => _newImage = File(image.path));
  }

  Future<void> _update() async {
    final customer = _customer;
    if (customer == null ||
        !(_formKey.currentState?.validate() ?? false) ||
        ref.read(editCustomerProvider).isLoading) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(editCustomerProvider.notifier)
        .update(
          original: customer,
          name: _name.text,
          phoneInput: _phone.text,
          address: _address.text,
          accountType: _accountType,
          notes: _notes.text,
          newImage: _newImage,
        );
  }

  Future<void> _confirmDelete() async {
    final customer = _customer;
    if (customer == null) return;
    final hasTransactions = await ref
        .read(customerRepositoryProvider)
        .hasTransactions(customer);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasTransactions ? 'Archive customer?' : 'Delete customer?'),
        content: Text(
          hasTransactions
              ? 'This customer has transactions and cannot be permanently '
                    'deleted. They will be archived while ledger history remains safe.'
              : 'This customer and their profile image will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(hasTransactions ? 'Archive' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(editCustomerProvider.notifier).delete(customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editCustomerProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == EditCustomerStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Something went wrong.')),
        );
      } else if (next.status == EditCustomerStatus.success &&
          next.customer != null) {
        final updated = next.customer!;
        ref.read(editCustomerProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully.')),
        );
        context.pop(updated);
      } else if (next.status == EditCustomerStatus.deleted) {
        final message = next.archived
            ? 'Customer archived. Transaction history was preserved.'
            : 'Customer deleted successfully.';
        ref.read(editCustomerProvider.notifier).reset();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        context.pop(next.customer);
      }
    });

    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    return customerAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (error, _) => _ErrorPage(
        message: error.toString().contains('permission')
            ? 'You do not have permission to access this customer.'
            : 'Could not load this customer.',
        onRetry: () => ref.invalidate(customerByIdProvider(widget.customerId)),
      ),
      data: (customer) {
        if (customer == null) {
          return _ErrorPage(
            message: 'Customer not found.',
            onRetry: () =>
                ref.invalidate(customerByIdProvider(widget.customerId)),
          );
        }
        _prefill(customer);
        return _buildForm(customer);
      },
    );
  }

  Widget _buildForm(CustomerModel customer) {
    final action = ref.watch(editCustomerProvider);
    final loading = action.isLoading;
    final label = switch (action.status) {
      EditCustomerStatus.uploading =>
        'Uploading ${(action.progress * 100).round()}%',
      EditCustomerStatus.deleting => 'Deleting...',
      _ => 'Updating...',
    };
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
          'Edit Customer',
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 125),
          children: [
            Center(
              child: InkWell(
                onTap: loading ? null : _pickImage,
                borderRadius: BorderRadius.circular(9),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EFFF),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _blue),
                      ),
                      child: _newImage != null
                          ? Image.file(_newImage!, fit: BoxFit.cover)
                          : customer.profileImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: customer.profileImage,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.add_a_photo_outlined,
                                color: _blue,
                              ),
                            )
                          : const Icon(
                              Icons.add_a_photo_outlined,
                              color: _blue,
                              size: 30,
                            ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Update Customer Photo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _Card(
              title: 'Basic Details',
              children: [
                _Input(
                  label: 'Customer Name *',
                  controller: _name,
                  hint: 'Enter full name',
                  validator: (value) => Validators.required(value, 'Name'),
                ),
                _Input(
                  label: 'Mobile Number *',
                  controller: _phone,
                  hint: '3xx-xxxxxxx number',
                  keyboardType: TextInputType.phone,
                  validator: Validators.pakistanPhone,
                ),
                const Text(
                  'Account Type',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: 'Customer',
                        selected: _accountType == 'customer',
                        onTap: () => setState(() => _accountType = 'customer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypeButton(
                        label: 'Supplier',
                        selected: _accountType == 'supplier',
                        onTap: () => setState(() => _accountType = 'supplier'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            _Card(
              title: 'Additional Info',
              children: [
                _Input(
                  label: 'Address',
                  controller: _address,
                  hint: 'Full address',
                  maxLines: 2,
                ),
                _Input(
                  label: 'Internal Notes',
                  controller: _notes,
                  hint: 'Special reminders or notes...',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: loading ? null : _confirmDelete,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete Customer'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 49,
            child: FilledButton.icon(
              onPressed: loading ? null : _update,
              style: FilledButton.styleFrom(backgroundColor: _blue),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(loading ? label : 'Update Customer'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _blue,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 10),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _field,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
  );
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
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
      height: 45,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _blue.withValues(alpha: .12) : _field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? _blue : _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _blue : _ink,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Edit Customer'),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: _muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}
