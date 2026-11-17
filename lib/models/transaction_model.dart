import 'dart:convert';
import '../core/utils/date_helpers.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.customerId,
    required this.transactionType,
    required this.amount,
    this.description = '',
    this.receiptUrl = '',
    this.previousBalance = 0,
    this.updatedBalance = 0,
    this.paymentMethod = 'Cash',
    required this.transactionDate,
    this.createdAt,
    this.updatedAt,
  });
  final String id,
      ownerId,
      businessId,
      customerId,
      transactionType,
      description,
      receiptUrl,
      paymentMethod;
  final double amount, previousBalance, updatedBalance;
  final DateTime transactionDate;
  final DateTime? createdAt, updatedAt;
  TransactionModel copyWith({
    String? id,
    String? transactionType,
    double? amount,
    String? description,
    String? receiptUrl,
    String? paymentMethod,
    DateTime? transactionDate,
    double? previousBalance,
    double? updatedBalance,
  }) => TransactionModel(
    id: id ?? this.id,
    ownerId: ownerId,
    businessId: businessId,
    customerId: customerId,
    transactionType: transactionType ?? this.transactionType,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    receiptUrl: receiptUrl ?? this.receiptUrl,
    previousBalance: previousBalance ?? this.previousBalance,
    updatedBalance: updatedBalance ?? this.updatedBalance,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  factory TransactionModel.fromMap(Map<String, dynamic> m, [String? id]) =>
      TransactionModel(
        id: id ?? m['id'] ?? '',
        ownerId: m['ownerId'] ?? 'local_user',
        businessId: m['businessId'] ?? '',
        customerId: m['customerId'] ?? '',
        transactionType: m['transactionType'] ?? m['type'] ?? 'gave',
        amount: (m['amount'] as num? ?? 0).toDouble(),
        description: m['description'] ?? '',
        receiptUrl: m['receiptUrl'] ?? '',
        previousBalance: (m['previousBalance'] as num? ?? 0).toDouble(),
        updatedBalance:
            (m['updatedBalance'] as num? ?? m['newBalance'] as num? ?? 0)
                .toDouble(),
        paymentMethod: m['paymentMethod'] ?? 'Cash',
        transactionDate: parseDate(m['transactionDate']) ?? DateTime.now(),
        createdAt: parseDate(m['createdAt']),
        updatedAt: parseDate(m['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'customerId': customerId,
    'transactionType': transactionType,
    'amount': amount,
    'description': description,
    'receiptUrl': receiptUrl,
    'previousBalance': previousBalance,
    'updatedBalance': updatedBalance,
    'paymentMethod': paymentMethod,
    'transactionDate': transactionDate.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory TransactionModel.fromJson(String s) =>
      TransactionModel.fromMap(jsonDecode(s));
  String toJson() => jsonEncode(toMap());
}
