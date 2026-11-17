class BackupModel {
  const BackupModel({
    required this.schemaVersion,
    required this.ownerId,
    required this.businessId,
    required this.createdAt,
    required this.user,
    required this.business,
    required this.collections,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String ownerId;
  final String businessId;
  final DateTime createdAt;
  final Map<String, dynamic> user;
  final Map<String, dynamic> business;
  final Map<String, List<Map<String, dynamic>>> collections;

  int get recordCount =>
      2 +
      collections.values.fold<int>(
        0,
        (total, records) => total + records.length,
      );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'ownerId': ownerId,
    'businessId': businessId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'user': user,
    'business': business,
    'collections': collections,
  };

  factory BackupModel.fromJson(Map<String, dynamic> json) {
    final rawCollections =
        json['collections'] as Map<String, dynamic>? ?? const {};
    return BackupModel(
      schemaVersion: (json['schemaVersion'] as num? ?? 0).toInt(),
      ownerId: json['ownerId'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      user: Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
      business: Map<String, dynamic>.from(json['business'] as Map? ?? const {}),
      collections: rawCollections.map(
        (key, value) => MapEntry(
          key,
          (value as List? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
        ),
      ),
    );
  }
}
