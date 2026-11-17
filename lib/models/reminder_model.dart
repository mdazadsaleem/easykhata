import '../core/utils/date_helpers.dart';

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.message,
    required this.dueDate,
    required this.status,
    required this.notificationId,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final String ownerId;
  final String businessId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double amount;
  final String message;
  final DateTime dueDate;
  final String status;
  final int notificationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());
  String get effectiveStatus => isOverdue ? 'overdue' : status;

  factory ReminderModel.fromMap(Map<String, dynamic> map, String id) =>
      ReminderModel(
        id: id,
        ownerId: map['ownerId'] ?? 'local_user',
        businessId: map['businessId'] ?? '',
        customerId: map['customerId'] ?? '',
        customerName: map['customerName'] ?? '',
        customerPhone: map['customerPhone'] ?? '',
        amount: (map['amount'] as num? ?? 0).toDouble(),
        message: map['message'] ?? '',
        dueDate: parseDate(map['dueDate']) ?? DateTime.now(),
        status: map['status'] == 'pending'
            ? 'upcoming'
            : map['status'] ?? 'upcoming',
        notificationId: (map['notificationId'] as num? ?? 0).toInt(),
        createdAt: parseDate(map['createdAt']),
        updatedAt: parseDate(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'amount': amount,
    'message': message,
    'dueDate': dueDate.toIso8601String(),
    'status': status,
    'notificationId': notificationId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
