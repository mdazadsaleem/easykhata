import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/validators.dart';
import '../../models/business_model.dart';
import '../../providers/business_details_providers.dart';
import '../../providers/business_providers.dart';

const _blue = Color(0xFF0733A2);
const _red = Color(0xFFD92D20);
const _muted = Color(0xFF687287);
const _page = Color(0xFFF5F6F9);
const _border = Color(0xFFD8DCE5);

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  ConsumerState<BusinessDetailsScreen> createState() =>
      _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends ConsumerState<BusinessDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerController = TextEditingController();
  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _picker = ImagePicker();

  static const _businessTypes = [
    'General Store',
    'Clothing',
    'Electronics',
    'Pharmacy',
    'Restaurant',
    'Wholesale',
    'Services',
    'Freelancer',
    'Other',
  ];
  static const _currencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR'];

  String? _loadedBusinessId;
  String _businessType = _businessTypes.first;
  String _currency = _currencies.first;
  File? _logo;

  @override
  void dispose() {
    _ownerController.dispose();
    _businessController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider);
    final action = ref.watch(businessDetailsActionProvider);
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text(
          'Business Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: business.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _BusinessError(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(currentBusinessProvider),
        ),
        data: (value) {
          if (value == null) {
            return _BusinessError(
              message: 'The selected business was not found.',
              onRetry: () => ref.invalidate(currentBusinessProvider),
            );
          }
          _prefill(value);
          return _form(value, action);
        },
      ),
    );
  }

  void _prefill(BusinessModel business) {
    if (_loadedBusinessId == business.id) return;
    _loadedBusinessId = business.id;
    _ownerController.text = business.ownerName;
    _businessController.text = business.businessName;
    _phoneController.text = business.phone;
    _addressController.text = business.address;
    _cityController.text = business.city;
    _businessType = _businessTypes.contains(business.businessType)
        ? business.businessType
        : 'Other';
    _currency = _currencies.contains(business.currency)
        ? business.currency
        : 'PKR';
  }

  Widget _form(BusinessModel business, BusinessDetailsActionState action) {
    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x22000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: const BorderSide(color: _border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: action.isBusy ? null : _pickLogo,
                        child: _LogoPicker(
                          logo: _logo,
                          currentUrl: business.logoUrl,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Business Logo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (action.isUploading) ...[
                      const SizedBox(height: 9),
                      LinearProgressIndicator(value: action.uploadProgress),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading logo '
                        '${(action.uploadProgress * 100).round()}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 8.5),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    _field(
                      label: 'Owner Name',
                      child: TextFormField(
                        controller: _ownerController,
                        enabled: !action.isBusy,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.required(value, 'Owner name'),
                      ),
                    ),
                    _field(
                      label: 'Business Name',
                      child: TextFormField(
                        controller: _businessController,
                        enabled: !action.isBusy,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.required(value, 'Business name'),
                      ),
                    ),
                    _field(
                      label: 'Business Type',
                      child: DropdownButtonFormField<String>(
                        initialValue: _businessType,
                        isExpanded: true,
                        items: _businessTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: action.isBusy
                            ? null
                            : (value) => setState(() => _businessType = value!),
                        validator: (value) =>
                            Validators.required(value, 'Business type'),
                      ),
                    ),
                    _field(
                      label: 'Phone',
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !action.isBusy,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: Validators.pakistanPhone,
                      ),
                    ),
                    _field(
                      label: 'Address',
                      child: TextFormField(
                        controller: _addressController,
                        enabled: !action.isBusy,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.required(value, 'Address'),
                      ),
                    ),
                    _field(
                      label: 'City',
                      child: TextFormField(
                        controller: _cityController,
                        enabled: !action.isBusy,
                        textInputAction: TextInputAction.done,
                        validator: (value) =>
                            Validators.required(value, 'City'),
                      ),
                    ),
                    _field(
                      label: 'Currency',
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        isExpanded: true,
                        items: _currencies
                            .map(
                              (currency) => DropdownMenuItem(
                                value: currency,
                                child: Text(currency),
                              ),
                            )
                            .toList(),
                        onChanged: action.isBusy
                            ? null
                            : (value) => setState(() => _currency = value!),
                        validator: (value) =>
                            Validators.required(value, 'Currency'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: action.isBusy ? null : () => _save(business),
                        icon: action.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 19),
                        label: Text(
                          action.isSaving ? 'Saving...' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (action.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        action.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 7),
        child,
      ],
    ),
  );

  Future<void> _pickLogo() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (selected == null || !mounted) return;
    if (await selected.length() > 5 * 1024 * 1024) {
      _message('The logo must be smaller than 5 MB.', error: true);
      return;
    }
    setState(() => _logo = File(selected.path));
  }

  Future<void> _save(BusinessModel business) async {
    FocusScope.of(context).unfocus();
    if (ref.read(businessDetailsActionProvider).isBusy ||
        _formKey.currentState?.validate() != true) {
      return;
    }
    final success = await ref
        .read(businessDetailsActionProvider.notifier)
        .save(
          BusinessDetailsInput(
            ownerName: _ownerController.text,
            businessName: _businessController.text,
            businessType: _businessType,
            phone: _phoneController.text,
            address: _addressController.text,
            city: _cityController.text,
            currency: _currency,
            logo: _logo,
          ),
        );
    if (!mounted) return;
    if (success) {
      setState(() => _logo = null);
      _message('Business details updated successfully.');
    } else {
      _message(
        ref.read(businessDetailsActionProvider).error ??
            'Could not save business details.',
        error: true,
      );
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: error ? _red : null),
      );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.logo, required this.currentUrl});
  final File? logo;
  final String currentUrl;

  @override
  Widget build(BuildContext context) {
    final provider = logo != null
        ? FileImage(logo!) as ImageProvider
        : currentUrl.isNotEmpty
        ? NetworkImage(currentUrl)
        : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6790E7)),
            image: provider == null
                ? null
                : DecorationImage(image: provider, fit: BoxFit.cover),
          ),
          child: provider == null
              ? const Icon(Icons.add_a_photo_outlined, color: _blue, size: 28)
              : null,
        ),
        Positioned(
          right: -5,
          bottom: -4,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessError extends StatelessWidget {
  const _BusinessError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _red, size: 46),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _errorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('selected')) return 'No business is currently selected.';
  if (text.contains('permission')) {
    return 'You do not have permission to access this business.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  return 'Could not load business details.';
}
