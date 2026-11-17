import 'dart:io';

import '../core/database/hive_database.dart';
import '../models/support_request_model.dart';
import 'storage_repository.dart';

class SupportRepository {
  SupportRepository(this._storage);

  final StorageRepository _storage;

  Future<String> submit({
    required SupportRequestModel request,
    File? screenshot,
    required void Function(double progress) onProgress,
  }) async {
    final id = 'sup_${DateTime.now().microsecondsSinceEpoch}';
    String screenshotUrl = '';
    if (screenshot != null) {
      screenshotUrl = await _storage.uploadWithProgress(
        path:
            'users/${request.ownerId}/support_requests/$id/'
            'screenshot_${DateTime.now().microsecondsSinceEpoch}.jpg',
        file: screenshot,
        onProgress: onProgress,
      );
    }
    final box = HiveDatabase.instance.supportBox;
    final now = DateTime.now().toIso8601String();
    await box.put(id, {
      'id': id,
      'ownerId': request.ownerId,
      'businessId': request.businessId,
      'subject': request.subject.trim(),
      'category': request.category,
      'description': request.description.trim(),
      'screenshotUrl': screenshotUrl,
      'deviceInfo': request.deviceInfo,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
    });
    onProgress(1);
    return id;
  }
}
