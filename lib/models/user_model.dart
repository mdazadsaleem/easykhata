import 'dart:convert';
import '../core/utils/date_helpers.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    this.name = '',
    this.email = '',
    this.profileImage = '',
    this.language = 'en',
    this.currency = 'PKR',
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });
  final String id, phone, name, email, profileImage, language, currency;
  final String? fcmToken;
  final DateTime? createdAt, updatedAt;
  UserModel copyWith({String? name, String? email, String? profileImage}) =>
      UserModel(
        id: id,
        phone: phone,
        name: name ?? this.name,
        email: email ?? this.email,
        profileImage: profileImage ?? this.profileImage,
        language: language,
        currency: currency,
        fcmToken: fcmToken,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
  factory UserModel.fromMap(Map<String, dynamic> m, [String? id]) => UserModel(
    id: id ?? m['id'] as String? ?? 'local_user',
    phone: m['phone'] as String? ?? '',
    name: m['name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    profileImage:
        m['profileImageUrl'] as String? ?? m['profileImage'] as String? ?? '',
    language: m['language'] as String? ?? 'en',
    currency: m['currency'] as String? ?? 'PKR',
    fcmToken: m['fcmToken'] as String?,
    createdAt: parseDate(m['createdAt']),
    updatedAt: parseDate(m['updatedAt']),
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'profileImage': profileImage,
    'profileImageUrl': profileImage,
    'language': language,
    'currency': currency,
    'fcmToken': fcmToken,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory UserModel.fromJson(String value) =>
      UserModel.fromMap(jsonDecode(value));
  String toJson() => jsonEncode(toMap());
}
