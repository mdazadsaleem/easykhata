import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveDatabase {
  static const String usersBoxName = 'users';
  static const String businessesBoxName = 'businesses';
  static const String customersBoxName = 'customers';
  static const String transactionsBoxName = 'transactions';
  static const String cashbookBoxName = 'cashbook_entries';
  static const String remindersBoxName = 'reminders';
  static const String notificationsBoxName = 'notifications';
  static const String backupsBoxName = 'backups';
  static const String supportBoxName = 'support_requests';

  static const String defaultUserId = 'local_user';

  static final HiveDatabase instance = HiveDatabase._();
  HiveDatabase._();

  bool _initialized = false;

  late Box<Map> usersBox;
  late Box<Map> businessesBox;
  late Box<Map> customersBox;
  late Box<Map> transactionsBox;
  late Box<Map> cashbookBox;
  late Box<Map> remindersBox;
  late Box<Map> notificationsBox;
  late Box<Map> backupsBox;
  late Box<Map> supportBox;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    usersBox = await Hive.openBox<Map>(usersBoxName);
    businessesBox = await Hive.openBox<Map>(businessesBoxName);
    customersBox = await Hive.openBox<Map>(customersBoxName);
    transactionsBox = await Hive.openBox<Map>(transactionsBoxName);
    cashbookBox = await Hive.openBox<Map>(cashbookBoxName);
    remindersBox = await Hive.openBox<Map>(remindersBoxName);
    notificationsBox = await Hive.openBox<Map>(notificationsBoxName);
    backupsBox = await Hive.openBox<Map>(backupsBoxName);
    supportBox = await Hive.openBox<Map>(supportBoxName);

    // Initialize default local user if not present
    if (!usersBox.containsKey(defaultUserId)) {
      final now = DateTime.now().toIso8601String();
      await usersBox.put(defaultUserId, {
        'id': defaultUserId,
        'name': 'Business Owner',
        'phone': '',
        'email': '',
        'profileImage': '',
        'language': 'en',
        'currency': 'PKR',
        'createdAt': now,
        'updatedAt': now,
      });
    }

    _initialized = true;
    debugPrint('HiveDatabase initialized successfully.');
  }

  Future<void> clearAll() async {
    await customersBox.clear();
    await transactionsBox.clear();
    await cashbookBox.clear();
    await remindersBox.clear();
    await notificationsBox.clear();
    await backupsBox.clear();
    await supportBox.clear();
    await businessesBox.clear();
    await usersBox.clear();

    // Recreate default user
    final now = DateTime.now().toIso8601String();
    await usersBox.put(defaultUserId, {
      'id': defaultUserId,
      'name': 'Business Owner',
      'phone': '',
      'email': '',
      'profileImage': '',
      'language': 'en',
      'currency': 'PKR',
      'createdAt': now,
      'updatedAt': now,
    });
  }
}
