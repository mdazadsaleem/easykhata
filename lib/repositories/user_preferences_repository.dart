import '../core/database/hive_database.dart';

class UserPreferencesRepository {
  UserPreferencesRepository();

  Future<void> updateLanguage({
    required String userId,
    required String languageCode,
  }) async {
    final box = HiveDatabase.instance.usersBox;
    final current = Map<String, dynamic>.from(box.get(userId) ?? <String, dynamic>{});
    current['id'] = userId;
    current['language'] = languageCode;
    current['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(userId, current);
  }

  Future<void> updateSettings({
    required String userId,
    bool? notificationsEnabled,
    String? dateFormat,
  }) async {
    final box = HiveDatabase.instance.usersBox;
    final current = Map<String, dynamic>.from(box.get(userId) ?? <String, dynamic>{});
    current['id'] = userId;
    if (notificationsEnabled != null) {
      current['notificationsEnabled'] = notificationsEnabled;
    }
    if (dateFormat != null) {
      current['dateFormat'] = dateFormat;
    }
    current['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(userId, current);
  }
}
