import '../core/utils/date_helpers.dart';

class BackupMetadataModel {
  const BackupMetadataModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.recordCount,
    required this.schemaVersion,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String ownerId;
  final String businessId;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final int recordCount;
  final int schemaVersion;
  final DateTime createdAt;
  final String status;

  factory BackupMetadataModel.fromMap(Map<String, dynamic> data, [String? id]) {
    return BackupMetadataModel(
      id: id ?? data['id'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? 'local_user',
      businessId: data['businessId'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      fileSize: (data['fileSize'] as num? ?? 0).toInt(),
      recordCount: (data['recordCount'] as num? ?? 0).toInt(),
      schemaVersion: (data['schemaVersion'] as num? ?? 0).toInt(),
      createdAt:
          parseDate(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status'] as String? ?? 'completed',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'storagePath': storagePath,
    'fileName': fileName,
    'fileSize': fileSize,
    'recordCount': recordCount,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };
}

class RestoreResult {
  const RestoreResult({required this.restored, required this.failed});
  final int restored;
  final int failed;
}
