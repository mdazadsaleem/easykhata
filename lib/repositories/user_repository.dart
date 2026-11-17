import '../core/database/hive_database.dart';
import 'auth_repository.dart';

class UserRepository {
  UserRepository();

  Future<bool> ensureUserDocument(LocalUser user) async {
    final box = HiveDatabase.instance.usersBox;
    if (box.containsKey(user.uid)) {
      final current = Map<String, dynamic>.from(box.get(user.uid)!);
      current['phone'] = user.phoneNumber ?? '';
      current['email'] = user.email ?? '';
      current['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(user.uid, current);
      return false;
    }

    final now = DateTime.now().toIso8601String();
    await box.put(user.uid, {
      'id': user.uid,
      'name': user.displayName ?? 'Business Owner',
      'phone': user.phoneNumber ?? '',
      'email': user.email ?? '',
      'profileImageUrl': '',
      'selectedBusinessId': '',
      'language': 'en',
      'currency': 'PKR',
      'themeMode': 'system',
      'fcmToken': '',
      'onboardingCompleted': true,
      'createdAt': now,
      'updatedAt': now,
    });
    return true;
  }
}
