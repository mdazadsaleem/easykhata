import 'dart:convert';
import '../core/utils/date_helpers.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.name,
    required this.phone,
    this.address = '',
    this.accountType = 'customer',
    this.openingBalance = 0,
    this.balanceType = 'settled',
    this.currentBalance = 0,
    this.profileImage = '',
    this.notes = '',
    this.isActive = true,
    this.lastTransactionAt,
    this.createdAt,
    this.updatedAt,
  });
  final String id,
      ownerId,
      businessId,
      name,
      phone,
      address,
      accountType,
      balanceType,
      profileImage,
      notes;
  final bool isActive;
  final double openingBalance, currentBalance;
  final DateTime? lastTransactionAt, createdAt, updatedAt;
  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? accountType,
    String? notes,
    String? profileImage,
    double? currentBalance,
    bool? isActive,
    DateTime? lastTransactionAt,
  }) => CustomerModel(
    id: id ?? this.id,
    ownerId: ownerId,
    businessId: businessId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    accountType: accountType ?? this.accountType,
    openingBalance: openingBalance,
    balanceType: balanceType,
    currentBalance: currentBalance ?? this.currentBalance,
    profileImage: profileImage ?? this.profileImage,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    lastTransactionAt: lastTransactionAt ?? this.lastTransactionAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  factory CustomerModel.fromMap(Map<String, dynamic> m, [String? id]) =>
      CustomerModel(
        id: id ?? m['id'] ?? '',
        ownerId: m['ownerId'] ?? 'local_user',
        businessId: m['businessId'] ?? '',
        name: m['name'] ?? '',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        accountType: m['accountType'] ?? 'customer',
        openingBalance: (m['openingBalance'] as num? ?? 0).toDouble(),
        balanceType: m['balanceDirection'] ?? m['balanceType'] ?? 'settled',
        currentBalance: (m['currentBalance'] as num? ?? 0).toDouble(),
        profileImage: m['profileImageUrl'] ?? m['profileImage'] ?? '',
        notes: m['notes'] ?? '',
        isActive: m['isActive'] as bool? ?? true,
        lastTransactionAt: parseDate(m['lastTransactionAt']),
        createdAt: parseDate(m['createdAt']),
        updatedAt: parseDate(m['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'businessId': businessId,
    'name': name,
    'phone': phone,
    'address': address,
    'accountType': accountType,
    'openingBalance': openingBalance,
    'balanceType': balanceType,
    'balanceDirection': balanceType,
    'currentBalance': currentBalance,
    'profileImage': profileImage,
    'profileImageUrl': profileImage,
    'notes': notes,
    'isActive': isActive,
    'lastTransactionAt': lastTransactionAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory CustomerModel.fromJson(String s) =>
      CustomerModel.fromMap(jsonDecode(s));
  String toJson() => jsonEncode(toMap());
}
