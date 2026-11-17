import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class StorageRepository {
  StorageRepository();

  Future<String> upload({required String path, required File file}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetFile = File('${appDir.path}/storage/$path');
    await targetFile.parent.create(recursive: true);
    await file.copy(targetFile.path);
    return targetFile.path;
  }

  Future<String> uploadWithProgress({
    required String path,
    required File file,
    required void Function(double progress) onProgress,
  }) async {
    onProgress(0.2);
    final appDir = await getApplicationDocumentsDirectory();
    final targetFile = File('${appDir.path}/storage/$path');
    await targetFile.parent.create(recursive: true);
    onProgress(0.6);
    await file.copy(targetFile.path);
    onProgress(1.0);
    return targetFile.path;
  }

  Future<void> deleteByUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final file = File(url);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<String> uploadData({
    required String path,
    required Uint8List data,
    String contentType = 'application/pdf',
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetFile = File('${appDir.path}/storage/$path');
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(data);
    return targetFile.path;
  }
}
