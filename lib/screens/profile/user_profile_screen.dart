import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/profile_providers.dart';

const _blue = Color(0xFF173EB5);
const _red = Color(0xFFD92D3A);
const _muted = Color(0xFF667085);
const _border = Color(0xFFDDE1EB);
const _page = Color(0xFFF8F9FD);

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _businessController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _loadedUserId;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final business = ref.watch(currentBusinessProvider);
    final action = ref.watch(profileActionProvider);

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileError(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (user) {
          _initializeControllers(user, business.value?.businessName ?? '');
          return _form(user, action);
        },
      ),
    );
  }

  void _initializeControllers(UserModel user, String businessName) {
    if (_loadedUserId == user.id) {
      if (_businessController.text != businessName) {
        _businessController.text = businessName;
      }
      return;
    }
    _loadedUserId = user.id;
    _nameController.text = user.name;
    _phoneController.text = user.phone;
    _emailController.text = user.email;
    _businessController.text = businessName;
  }

  Widget _form(UserModel user, ProfileActionState action) {
    final busy = action.isSaving || action.isUploading;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 30),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFE8EEFF),
                  backgroundImage: user.profileImage.isEmpty
                      ? null
                      : NetworkImage(user.profileImage),
                  child: user.profileImage.isEmpty
                      ? Text(
                          _initials(user.name),
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: _blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: busy ? null : () => _pickImage(user),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action.isUploading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: action.uploadProgress),
            const SizedBox(height: 6),
            Text(
              'Uploading ${(action.uploadProgress * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your full name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    suffixIcon: Icon(Icons.lock_outline_rounded, size: 17),
                    helperText:
                        'Phone verification is required to change this number.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Current business',
                    prefixIcon: Icon(Icons.business_outlined),
                    suffixIcon: Icon(Icons.lock_outline_rounded, size: 17),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: action.isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(action.isSaving ? 'Saving...' : 'Save changes'),
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
    );
  }

  Future<void> _pickImage(UserModel user) async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (selected == null || !mounted) return;
      final success = await ref
          .read(profileActionProvider.notifier)
          .uploadImage(
            image: File(selected.path),
            oldImageUrl: user.profileImage,
          );
      if (!mounted) return;
      _message(
        success
            ? 'Profile image updated successfully.'
            : ref.read(profileActionProvider).error ?? 'Image upload failed.',
        error: !success,
      );
    } catch (error) {
      if (mounted) _message(_errorMessage(error), error: true);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    final success = await ref
        .read(profileActionProvider.notifier)
        .save(name: _nameController.text, email: _emailController.text);
    if (!mounted) return;
    _message(
      success
          ? 'Profile updated successfully.'
          : ref.read(profileActionProvider).error ?? 'Profile update failed.',
      error: !success,
    );
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value), backgroundColor: error ? _red : null),
      );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
    ).hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});
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

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'SK';
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}

String _errorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission')) {
    return 'You do not have permission to update this profile.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
