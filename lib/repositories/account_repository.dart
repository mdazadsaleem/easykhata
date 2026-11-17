import '../core/database/hive_database.dart';

class AccountRepository {
  AccountRepository();

  Future<List<String>> backupStoragePaths(String ownerId) async {
    final box = HiveDatabase.instance.backupsBox;
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((b) => b['ownerId'] == ownerId)
        .map((b) => b['storagePath'] as String? ?? '')
        .where((path) => path.isNotEmpty)
        .toList();
  }

  Future<List<String>> ownerDataReferences(String ownerId) async {
    return [ownerId];
  }

  Future<void> deleteReferencesInBatches({
    required List<String> references,
    required void Function(int deleted, int total) onProgress,
  }) async {
    await HiveDatabase.instance.clearAll();
    onProgress(1, 1);
  }

  Future<void> deleteUserDocument(String ownerId) async {
    await HiveDatabase.instance.usersBox.delete(ownerId);
  }
}
