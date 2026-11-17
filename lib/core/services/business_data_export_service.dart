import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/hive_database.dart';

class BusinessDataExportService {
  BusinessDataExportService();

  Future<File> createBackup({
    required String ownerId,
    required String businessId,
  }) async {
    final bizData = HiveDatabase.instance.businessesBox.get(businessId);
    if (bizData == null) {
      throw StateError('Business was not found.');
    }

    final content = <String, dynamic>{
      'formatVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'businessId': businessId,
      'business': Map<String, dynamic>.from(bizData),
    };

    content['customers'] = HiveDatabase.instance.customersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
        .toList();

    content['transactions'] = HiveDatabase.instance.transactionsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((t) => t['ownerId'] == ownerId && t['businessId'] == businessId)
        .toList();

    content['cashbook_entries'] = HiveDatabase.instance.cashbookBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
        .toList();

    content['reminders'] = HiveDatabase.instance.remindersBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['ownerId'] == ownerId && r['businessId'] == businessId)
        .toList();

    content['notifications'] = HiveDatabase.instance.notificationsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((n) => n['ownerId'] == ownerId && n['businessId'] == businessId)
        .toList();

    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'smart_khata_backup_$stamp.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(content),
      flush: true,
    );
    return file;
  }

  Future<void> shareBackup(File file) {
    return SharePlus.instance.share(
      ShareParams(
        text: 'Smart Khata business data export',
        files: [XFile(file.path, mimeType: 'application/json')],
      ),
    );
  }
}
