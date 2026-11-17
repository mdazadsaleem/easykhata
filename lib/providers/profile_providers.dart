import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/profile_repository.dart';
import 'app_providers.dart';

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(storageRepositoryProvider),
  ),
);

final userProfileProvider = StreamProvider<UserModel>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.error(StateError('You are not signed in.'));
  }
  return ref.watch(profileRepositoryProvider).watch(user.uid);
});

class ProfileActionState {
  const ProfileActionState({
    this.isSaving = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
  });

  final bool isSaving;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
}

final profileActionProvider =
    NotifierProvider<ProfileActionNotifier, ProfileActionState>(
      ProfileActionNotifier.new,
    );

class ProfileActionNotifier extends Notifier<ProfileActionState> {
  @override
  ProfileActionState build() => const ProfileActionState();

  Future<bool> save({required String name, required String email}) async {
    if (state.isSaving || state.isUploading) return false;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const ProfileActionState(error: 'You are not signed in.');
      return false;
    }
    state = const ProfileActionState(isSaving: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateDetails(uid: user.uid, name: name, email: email);
      state = const ProfileActionState();
      return true;
    } catch (error) {
      state = ProfileActionState(error: _profileError(error));
      return false;
    }
  }

  Future<bool> uploadImage({
    required File image,
    required String oldImageUrl,
  }) async {
    if (state.isSaving || state.isUploading) return false;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const ProfileActionState(error: 'You are not signed in.');
      return false;
    }
    state = const ProfileActionState(isUploading: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .replaceProfileImage(
            uid: user.uid,
            image: image,
            oldImageUrl: oldImageUrl,
            onProgress: (progress) {
              state = ProfileActionState(
                isUploading: true,
                uploadProgress: progress,
              );
            },
          );
      state = const ProfileActionState();
      return true;
    } catch (error) {
      state = ProfileActionState(error: _profileError(error));
      return false;
    }
  }
}

String _profileError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission')) {
    return 'You do not have permission to update this profile.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'Could not load data. Please try again.';
  }
  if (text.contains('object-not-found')) {
    return 'Could not save the selected image. Please try again.';
  }
  return 'Profile update failed. Please try again.';
}
