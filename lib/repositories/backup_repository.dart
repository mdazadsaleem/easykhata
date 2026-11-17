import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/database/hive_database.dart';
import '../core/utils/backup_json_helpers.dart';
import '../models/backup_metadata_model.dart';
import '../models/backup_model.dart';

class BackupRepository {
  BackupRepository();

  Stream<List<BackupMetadataModel>> watchBackups({
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.backupsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final list = box.values
            .map((e) => BackupMetadataModel.fromMap(
                Map<String, dynamic>.from(e), e['id']))
            .where((b) => b.ownerId == ownerId && b.businessId == businessId)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(list);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<BackupMetadataModel> createBackup({
    required String ownerId,
    required String businessId,
    required void Function(double progress) onProgress,
  }) async {
    onProgress(0.1);
    final userBox = HiveDatabase.instance.usersBox;
    final bizBox = HiveDatabase.instance.businessesBox;

    final userData = userBox.get(ownerId) ?? <String, dynamic>{};
    final bizData = bizBox.get(businessId);
    if (bizData == null) {
      throw StateError('Business was not found.');
    }

    final collections = <String, List<Map<String, dynamic>>>{};
    collections['customers'] = HiveDatabase.instance.customersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
        .map((c) => {'id': c['id'], 'data': jsonSafeMap(c)})
        .toList();

    collections['transactions'] = HiveDatabase.instance.transactionsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((t) => t['ownerId'] == ownerId && t['businessId'] == businessId)
        .map((t) => {'id': t['id'], 'data': jsonSafeMap(t)})
        .toList();

    collections['cashbook_entries'] = HiveDatabase.instance.cashbookBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
        .map((c) => {'id': c['id'], 'data': jsonSafeMap(c)})
        .toList();

    collections['reminders'] = HiveDatabase.instance.remindersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['ownerId'] == ownerId && r['businessId'] == businessId)
        .map((r) => {'id': r['id'], 'data': jsonSafeMap(r)})
        .toList();

    collections['notifications'] = HiveDatabase.instance.notificationsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((n) => n['ownerId'] == ownerId && n['businessId'] == businessId)
        .map((n) => {'id': n['id'], 'data': jsonSafeMap(n)})
        .toList();

    onProgress(0.4);

    final backup = BackupModel(
      schemaVersion: BackupModel.currentSchemaVersion,
      ownerId: ownerId,
      businessId: businessId,
      createdAt: DateTime.now(),
      user: jsonSafeMap(Map<String, dynamic>.from(userData)),
      business: jsonSafeMap(Map<String, dynamic>.from(bizData)),
      collections: collections,
    );

    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/backups/$ownerId/$businessId');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final stamp = backup.createdAt.toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final fileName = 'smart_khata_backup_$stamp.json';
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsString(jsonEncode(backup.toJson()), flush: true);

    final fileSize = await file.length();
    onProgress(0.8);

    final id = 'bk_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = {
      'id': id,
      'ownerId': ownerId,
      'businessId': businessId,
      'storagePath': file.path,
      'fileName': fileName,
      'fileSize': fileSize,
      'recordCount': backup.recordCount,
      'schemaVersion': backup.schemaVersion,
      'status': 'completed',
      'createdAt': backup.createdAt.toIso8601String(),
    };

    await HiveDatabase.instance.backupsBox.put(id, metadata);
    onProgress(1.0);

    return BackupMetadataModel.fromMap(metadata, id);
  }

  Future<File> downloadBackup(
    BackupMetadataModel metadata, {
    required String ownerId,
    required String businessId,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    final file = File(metadata.storagePath);
    if (!await file.exists()) {
      final directory = await getApplicationDocumentsDirectory();
      final altFile = File(
        '${directory.path}/backups/$ownerId/$businessId/${metadata.fileName}',
      );
      if (await altFile.exists()) return altFile;
      throw StateError('Backup file not found on device.');
    }
    onProgress?.call(1.0);
    return file;
  }

  Future<BackupModel> readAndValidate({
    required BackupMetadataModel metadata,
    required String ownerId,
    required String businessId,
    void Function(double progress)? onProgress,
  }) async {
    final file = await downloadBackup(
      metadata,
      ownerId: ownerId,
      businessId: businessId,
      onProgress: onProgress,
    );
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    final backup = BackupModel.fromJson(decoded);
    if (backup.ownerId != ownerId || backup.businessId != businessId) {
      throw StateError('This backup belongs to another account or business.');
    }
    if (backup.schemaVersion != BackupModel.currentSchemaVersion ||
        metadata.schemaVersion != BackupModel.currentSchemaVersion) {
      throw StateError('This backup version is not supported.');
    }
    return backup;
  }

  Future<RestoreResult> restore({
    required BackupModel backup,
    required String ownerId,
    required String businessId,
    required void Function(double progress) onProgress,
  }) async {
    if (backup.ownerId != ownerId || backup.businessId != businessId) {
      throw StateError('Backup ownership validation failed.');
    }

    onProgress(0.1);
    var restored = 0;
    var failed = 0;

    try {
      await HiveDatabase.instance.usersBox.put(ownerId, {
        ...backup.user,
        'selectedBusinessId': businessId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      restored++;

      await HiveDatabase.instance.businessesBox.put(businessId, {
        ...backup.business,
        'id': businessId,
        'ownerId': ownerId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      restored++;

      onProgress(0.3);

      for (final entry in backup.collections.entries) {
        final boxName = entry.key;
        final list = entry.value;
        for (final item in list) {
          try {
            final id = item['id'] as String;
            final data = Map<String, dynamic>.from(item['data'] as Map);
            data['id'] = id;
            data['ownerId'] = ownerId;
            data['businessId'] = businessId;

            if (boxName == 'customers') {
              await HiveDatabase.instance.customersBox.put(id, data);
            } else if (boxName == 'transactions') {
              await HiveDatabase.instance.transactionsBox.put(id, data);
            } else if (boxName == 'cashbook_entries') {
              await HiveDatabase.instance.cashbookBox.put(id, data);
            } else if (boxName == 'reminders') {
              await HiveDatabase.instance.remindersBox.put(id, data);
            } else if (boxName == 'notifications') {
              await HiveDatabase.instance.notificationsBox.put(id, data);
            }
            restored++;
          } catch (_) {
            failed++;
          }
        }
      }
      onProgress(1.0);
    } catch (_) {
      failed++;
    }

    return RestoreResult(restored: restored, failed: failed);
  }

  Future<void> deleteBackup({
    required BackupMetadataModel metadata,
    required String ownerId,
    required String businessId,
  }) async {
    final file = File(metadata.storagePath);
    if (await file.exists()) {
      await file.delete();
    }
    await HiveDatabase.instance.backupsBox.delete(metadata.id);
  }

  Future<void> saveAutomaticPreference({
    required String ownerId,
    required bool enabled,
    required String frequency,
  }) async {
    final userBox = HiveDatabase.instance.usersBox;
    final userData = Map<String, dynamic>.from(userBox.get(ownerId) ?? <String, dynamic>{});
    userData['automaticBackupEnabled'] = enabled;
    userData['automaticBackupFrequency'] = frequency;
    await userBox.put(ownerId, userData);
  }
}
