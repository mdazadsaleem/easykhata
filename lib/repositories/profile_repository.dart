import 'dart:io';

import '../core/database/hive_database.dart';
import '../models/user_model.dart';
import 'storage_repository.dart';

class ProfileRepository {
  ProfileRepository(this._storage);

  final StorageRepository _storage;

  Stream<UserModel> watch(String uid) {
    final box = HiveDatabase.instance.usersBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final data = box.get(uid);
        if (data != null) {
          controller.add(UserModel.fromMap(Map<String, dynamic>.from(data), uid));
        } else {
          controller.add(UserModel(id: uid, phone: ''));
        }
      }

      emit();
      final sub = box.watch(key: uid).listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<void> updateDetails({
    required String uid,
    required String name,
    required String email,
  }) async {
    final box = HiveDatabase.instance.usersBox;
    final data = Map<String, dynamic>.from(box.get(uid) ?? <String, dynamic>{});
    data['id'] = uid;
    data['name'] = name.trim();
    data['email'] = email.trim().toLowerCase();
    data['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(uid, data);
  }

  Future<String> replaceProfileImage({
    required String uid,
    required File image,
    required String oldImageUrl,
    required void Function(double progress) onProgress,
  }) async {
    final path =
        'users/$uid/profile/profile_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final newUrl = await _storage.uploadWithProgress(
      path: path,
      file: image,
      onProgress: onProgress,
    );

    final box = HiveDatabase.instance.usersBox;
    final data = Map<String, dynamic>.from(box.get(uid) ?? <String, dynamic>{});
    data['id'] = uid;
    data['profileImage'] = newUrl;
    data['profileImageUrl'] = newUrl;
    data['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(uid, data);

    if (oldImageUrl.isNotEmpty && oldImageUrl != newUrl) {
      await _storage.deleteByUrl(oldImageUrl);
    }
    return newUrl;
  }
}
