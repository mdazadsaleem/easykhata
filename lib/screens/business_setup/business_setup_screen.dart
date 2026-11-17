import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../providers/app_providers.dart';
import '../../providers/business_providers.dart';
import '../../providers/business_setup_providers.dart';
import '../../providers/startup_providers.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
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

  String _businessType = _businessTypes.first;
  File? _logo;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _ownerController.text = user?.displayName ?? '';
    _phoneController.text = (user?.phoneNumber ?? '').replaceFirst('+92', '');
  }

  Future<void> _pickLogo() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (selected == null) return;

    final extension = selected.path.split('.').last.toLowerCase();
    final supported = {'jpg', 'jpeg', 'png', 'webp'};
    if (!supported.contains(extension)) {
      _showMessage('Choose a JPG, PNG, or WebP image.');
      return;
    }
    if (await selected.length() > 5 * 1024 * 1024) {
      _showMessage('The logo must be smaller than 5 MB.');
      return;
    }
    setState(() => _logo = File(selected.path));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (ref.read(businessSetupProvider).isLoading ||
        !_formKey.currentState!.validate()) {
      return;
    }
    _navigationStarted = false;
    await ref
        .read(businessSetupProvider.notifier)
        .create(
          BusinessSetupInput(
            ownerName: _ownerController.text,
            businessName: _businessController.text,
            businessType: _businessType,
            phone: _phoneController.text,
            address: _addressController.text,
            city: _cityController.text,
            logo: _logo,
          ),
        );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
    final setup = ref.watch(businessSetupProvider);
    ref.listen<BusinessSetupState>(businessSetupProvider, (previous, next) {
      if (next.status == BusinessSetupStatus.error &&
          next.message != null &&
          next.message != previous?.message) {
        _showMessage(next.message!);
        if (next.message!.contains('session expired')) {
          context.go(AppRoutes.login);
        }
      }
      if (!_navigationStarted && next.status == BusinessSetupStatus.success) {
        _navigationStarted = true;
        ref.invalidate(currentBusinessProvider);
        ref.invalidate(businessCompletionProvider);
        ref.invalidate(startupProvider);
        _showMessage(next.message ?? 'Business created successfully.');
        context.go(AppRoutes.main);
      }
    });
    final loading = setup.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text(
          'Business Setup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Business setup help',
            onPressed: () => _showMessage(
              'Add your business details. You can update them later in Settings.',
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
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
                  side: const BorderSide(color: Color(0xFFD8DCE5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: loading ? null : _pickLogo,
                          child: _LogoPicker(logo: _logo),
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Upload Business Logo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF07152B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (setup.status == BusinessSetupStatus.uploading) ...[
                        const SizedBox(height: 9),
                        LinearProgressIndicator(value: setup.uploadProgress),
                        const SizedBox(height: 4),
                        Text(
                          'Uploading logo ${(setup.uploadProgress * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5B6578),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      const Text(
                        'Recommended size: 500×500px',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF5B6578),
                          fontSize: 8.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFE5E8EF)),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        icon: Icons.person_outline_rounded,
                        title: 'BASIC INFORMATION',
                      ),
                      const SizedBox(height: 20),
                      _FieldLabel(
                        label: 'Owner Name',
                        child: TextFormField(
                          controller: _ownerController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              Validators.required(value, 'Owner name'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Ahmad Khan',
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _FieldLabel(
                        label: 'Business Name',
                        child: TextFormField(
                          controller: _businessController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              Validators.required(value, 'Business name'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Khan General Store',
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _FieldLabel(
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
                          onChanged: loading
                              ? null
                              : (value) =>
                                    setState(() => _businessType = value!),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _FieldLabel(
                        label: 'Mobile Number',
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: Validators.pakistanPhone,
                          decoration: const InputDecoration(
                            prefixText: '+92   ',
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const _SectionTitle(
                        icon: Icons.location_on_outlined,
                        title: 'BUSINESS ADDRESS',
                      ),
                      const SizedBox(height: 20),
                      _FieldLabel(
                        label: 'Street Address',
                        child: TextFormField(
                          controller: _addressController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              Validators.required(value, 'Street address'),
                          decoration: const InputDecoration(
                            hintText: 'Shop #12, Market Square...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _FieldLabel(
                        label: 'City',
                        child: TextFormField(
                          controller: _cityController,
                          textInputAction: TextInputAction.done,
                          validator: (value) =>
                              Validators.required(value, 'City'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Lahore',
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const _FieldLabel(
                        label: 'Currency',
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'PKR (Default)',
                            suffixIcon: Icon(
                              Icons.lock_outline_rounded,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Currency is locked to PKR for local compliance.',
                        style: TextStyle(color: Color(0xFF687287), fontSize: 8),
                      ),
                      const SizedBox(height: 27),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0733A2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 3,
                            shadowColor: const Color(0x400733A2),
                          ),
                          onPressed: loading ? null : _save,
                          child: loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Create Business',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 9),
                                    Icon(
                                      Icons.rocket_launch_outlined,
                                      size: 19,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text.rich(
                        TextSpan(
                          text: 'By creating a business, you agree to our\n',
                          children: [
                            TextSpan(
                              text: 'Terms of Service.',
                              style: TextStyle(
                                color: Color(0xFF0733A2),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF596579),
                          fontSize: 9.5,
                          height: 1.45,
                        ),
                      ),
                    ],
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

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({this.logo});

  final File? logo;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFFE7EEFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6790E7)),
          image: logo == null
              ? null
              : DecorationImage(image: FileImage(logo!), fit: BoxFit.cover),
        ),
        child: logo == null
            ? const Icon(
                Icons.add_a_photo_outlined,
                color: Color(0xFF0733A2),
                size: 28,
              )
            : null,
      ),
      Positioned(
        right: -5,
        bottom: -4,
        child: Container(
          width: 21,
          height: 21,
          decoration: const BoxDecoration(
            color: Color(0xFF0733A2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF0733A2), size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0733A2),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF26364F),
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 7),
      Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFF7F8FC),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            hintStyle: TextStyle(color: Color(0xFF69758A), fontSize: 10.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              borderSide: BorderSide(color: Color(0xFFD4D9E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              borderSide: BorderSide(color: Color(0xFFD4D9E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              borderSide: BorderSide(color: Color(0xFF1749CD), width: 1.3),
            ),
          ),
        ),
        child: child,
      ),
    ],
  );
}
