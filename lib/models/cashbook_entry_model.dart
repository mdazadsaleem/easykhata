import '../core/utils/date_helpers.dart';

class CashbookEntryModel {
  const CashbookEntryModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.paymentMethod,
    required this.entryDate,
    this.receiptUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String businessId;
  final String type;
  final double amount;
  final String category;
  final String description;
  final String paymentMethod;
  final String receiptUrl;
  final DateTime entryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCashIn => type == 'cashIn';

  factory CashbookEntryModel.fromMap(Map<String, dynamic> map, String id) =>
      CashbookEntryModel(
        id: id,
        ownerId: map['ownerId'] ?? 'local_user',
        businessId: map['businessId'] ?? '',
        type: map['type'] ?? 'cashIn',
        amount: (map['amount'] as num? ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        description: map['description'] ?? '',
        paymentMethod: map['paymentMethod'] ?? 'Cash',
        receiptUrl: map['receiptUrl'] ?? '',
        entryDate: parseDate(map['entryDate']) ?? DateTime.now(),
        createdAt: parseDate(map['createdAt']),
        updatedAt: parseDate(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'type': type,
    'amount': amount,
    'category': category,
    'description': description,
    'paymentMethod': paymentMethod,
    'receiptUrl': receiptUrl,
    'entryDate': entryDate.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
