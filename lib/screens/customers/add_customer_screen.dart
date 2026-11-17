import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../providers/add_customer_provider.dart';
import '../../providers/auth_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF00A66A);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD9DEEA);
const _field = Color(0xFFF4F6FC);
const _page = Color(0xFFF8F9FD);

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  String _accountType = 'customer';
  String _balanceType = 'receivable';
  File? _photo;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 900,
    );
    if (selected != null && mounted) {
      setState(() => _photo = File(selected.path));
    }
  }

  Future<void> _pickContact() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contacts permission is needed to select a number.',
              ),
            ),
          );
        }
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
      );
      if (fullContact == null || fullContact.phones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This contact has no phone number.')),
          );
        }
        return;
      }
      final normalized = normalizePakistanPhone(
        fullContact.phones.first.number,
      );
      if (normalized == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The selected contact has no valid Pakistani number.',
              ),
            ),
          );
        }
        return;
      }
      _phoneController.text = normalized.substring(3);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = fullContact.displayName;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open your contacts.')),
        );
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _balanceController.text = '0.00';
    _notesController.clear();
    _photo = null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        ref.read(addCustomerProvider).isLoading) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(addCustomerProvider.notifier)
        .create(
          AddCustomerInput(
            name: _nameController.text,
            phone: _phoneController.text,
            accountType: _accountType,
            address: _addressController.text,
            openingBalance:
                double.tryParse(_balanceController.text.trim()) ?? 0,
            balanceDirection: _balanceType,
            notes: _notesController.text,
            profileImage: _photo,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(addCustomerProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == AddCustomerStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      } else if (next.status == AddCustomerStatus.success &&
          next.createdCustomer != null) {
        final createdCustomer = next.createdCustomer!;
        _clearForm();
        ref.read(addCustomerProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved successfully.')),
        );
        context.pop(createdCustomer);
      }
    });
    final saveState = ref.watch(addCustomerProvider);
    final loading = saveState.isLoading;
    final loadingLabel = saveState.status == AddCustomerStatus.uploading
        ? 'Uploading ${(saveState.uploadProgress * 100).round()}%'
        : 'Saving...';
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
          'Add New Customer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            Center(
              child: InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(9),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EFFF),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _blue,
                              style: BorderStyle.solid,
                            ),
                            image: _photo == null
                                ? null
                                : DecorationImage(
                                    image: FileImage(_photo!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: _photo == null
                              ? const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: _blue,
                                  size: 30,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Customer Photo',
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
            _FormCard(
              title: 'Basic Details',
              children: [
                const _FieldLabel('Customer Name *'),
                _Input(
                  controller: _nameController,
                  hint: 'Enter full name',
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(value, 'Name'),
                ),
                const SizedBox(height: 13),
                const _FieldLabel('Mobile Number'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: loading ? null : _pickContact,
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _field,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(5),
                          ),
                          border: Border.all(color: _border),
                        ),
                        child: const Text(
                          '+92',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Input(
                        controller: _phoneController,
                        hint: '3xx-xxxxxxx number',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        joinedRight: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required.';
                          }
                          return Validators.pakistanPhone(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                const _FieldLabel('Account Type'),
                _TwoOptionSelector(
                  leftLabel: 'Customer',
                  leftIcon: Icons.person_outline_rounded,
                  rightLabel: 'Supplier',
                  rightIcon: Icons.local_shipping_outlined,
                  leftSelected: _accountType == 'customer',
                  selectedColor: _blue,
                  onLeft: () => setState(() => _accountType = 'customer'),
                  onRight: () => setState(() => _accountType = 'supplier'),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _FormCard(
              title: 'Financials',
              children: [
                const _FieldLabel('Opening Balance'),
                _Input(
                  controller: _balanceController,
                  hint: '0.00',
                  prefixText: '₨  ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || amount < 0
                        ? 'Enter a valid balance.'
                        : null;
                  },
                ),
                const SizedBox(height: 13),
                const _FieldLabel('Balance Type'),
                _TwoOptionSelector(
                  leftLabel: 'You Will Receive',
                  leftIcon: Icons.south_west_rounded,
                  rightLabel: 'You Will Pay',
                  rightIcon: Icons.north_east_rounded,
                  leftSelected: _balanceType == 'receivable',
                  selectedColor: _green,
                  onLeft: () => setState(() => _balanceType = 'receivable'),
                  onRight: () => setState(() => _balanceType = 'payable'),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _FormCard(
              title: 'Additional Info',
              children: [
                const _FieldLabel('Address'),
                _Input(
                  controller: _addressController,
                  hint: 'Full address',
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 13),
                const _FieldLabel('Internal Notes'),
                _Input(
                  controller: _notesController,
                  hint: 'Special reminders or notes...',
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
              ],
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
              onPressed: loading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                loading ? loadingLabel : 'Save Customer',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});
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

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.prefixText,
    this.maxLines = 1,
    this.maxLength,
    this.joinedRight = false,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final String? prefixText;
  final int maxLines;
  final int? maxLength;
  final bool joinedRight;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    validator: validator,
    maxLines: maxLines,
    maxLength: maxLength,
    style: const TextStyle(fontSize: 10),
    decoration: InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      counterText: '',
      hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9),
      filled: true,
      fillColor: _field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(joinedRight ? 0 : 5),
          right: const Radius.circular(5),
        ),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(joinedRight ? 0 : 5),
          right: const Radius.circular(5),
        ),
        borderSide: const BorderSide(color: _border),
      ),
    ),
  );
}

class _TwoOptionSelector extends StatelessWidget {
  const _TwoOptionSelector({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.leftSelected,
    required this.selectedColor,
    required this.onLeft,
    required this.onRight,
  });
  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final bool leftSelected;
  final Color selectedColor;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _OptionButton(
          label: leftLabel,
          icon: leftIcon,
          selected: leftSelected,
          color: selectedColor,
          onTap: onLeft,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _OptionButton(
          label: rightLabel,
          icon: rightIcon,
          selected: !leftSelected,
          color: selectedColor,
          onTap: onRight,
        ),
      ),
    ],
  );
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      height: 52,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .13) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? color : _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: selected ? color : _muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? color : _ink,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
