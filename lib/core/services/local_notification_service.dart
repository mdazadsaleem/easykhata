import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize({bool requestPermission = true}) async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _initialized = true;
    }
    if (requestPermission && !_permissionRequested) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _permissionRequested = true;
    }
  }

  Future<void> schedule({
    required int id,
    required String customerName,
    required String message,
    required DateTime dueDate,
  }) async {
    await initialize();
    if (!dueDate.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: 'Payment Reminder: $customerName',
      body: message,
      scheduledDate: tz.TZDateTime.from(dueDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_reminders',
          'Payment Reminders',
          channelDescription: 'Scheduled Smart Khata payment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await initialize(requestPermission: false);
    await _plugin.cancelAll();
  }
}
