import '../core/utils/date_helpers.dart';

enum AppNotificationType {
  paymentReminder('payment_reminder'),
  overduePayment('overdue_payment'),
  backupCompletion('backup_completion'),
  businessAlert('business_alert'),
  generalAnnouncement('general_announcement');

  const AppNotificationType(this.value);
  final String value;

  static AppNotificationType fromValue(String? value) {
    return AppNotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AppNotificationType.generalAnnouncement,
    );
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
    this.readAt,
  });

  final String id;
  final String ownerId;
  final String businessId;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? referenceId;
  final DateTime? readAt;

  factory AppNotificationModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return AppNotificationModel(
      id: id,
      ownerId: data['ownerId'] as String? ?? 'local_user',
      businessId: data['businessId'] as String? ?? '',
      type: AppNotificationType.fromValue(data['type'] as String?),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? data['message'] as String? ?? '',
      isRead: data['isRead'] == true,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      referenceId: data['referenceId'] as String?,
      readAt: parseDate(data['readAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'type': type.value,
    'title': title,
    'body': body,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'referenceId': referenceId,
    'readAt': readAt?.toIso8601String(),
  };
}
