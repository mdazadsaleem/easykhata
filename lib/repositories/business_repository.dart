import '../core/database/hive_database.dart';
import '../models/business_model.dart';

class BusinessRepository {
  BusinessRepository();

  String newBusinessId() =>
      'biz_${DateTime.now().microsecondsSinceEpoch}';

  Stream<BusinessModel?> watchForOwner(String uid) {
    final box = HiveDatabase.instance.businessesBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final list = box.values
            .map((e) => BusinessModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((b) => b.ownerId == uid)
            .toList();
        controller.add(list.isEmpty ? null : list.first);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<String> selectedBusinessId(String uid) async {
    final userBox = HiveDatabase.instance.usersBox;
    final user = userBox.get(uid);
    final selected = (user?['selectedBusinessId'] as String? ?? '').trim();

    final bizBox = HiveDatabase.instance.businessesBox;
    if (selected.isNotEmpty && bizBox.containsKey(selected)) {
      return selected;
    }

    final owned = bizBox.values
        .map((e) => BusinessModel.fromMap(Map<String, dynamic>.from(e), e['id']))
        .where((b) => b.ownerId == uid)
        .toList();
    if (owned.isEmpty) {
      throw StateError('No business is available for this account.');
    }

    final businessId = owned.first.id;
    if (user != null) {
      final updatedUser = Map<String, dynamic>.from(user);
      updatedUser['selectedBusinessId'] = businessId;
      await userBox.put(uid, updatedUser);
    }
    return businessId;
  }

  Stream<BusinessModel?> watchById({
    required String businessId,
    required String ownerId,
  }) {
    final box = HiveDatabase.instance.businessesBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final data = box.get(businessId);
        if (data == null) {
          controller.add(null);
          return;
        }
        final biz = BusinessModel.fromMap(Map<String, dynamic>.from(data), businessId);
        if (biz.ownerId != ownerId) {
          controller.addError(
            StateError('You do not have permission to access this business.'),
          );
          return;
        }
        controller.add(biz);
      }

      emit();
      final sub = box.watch(key: businessId).listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<String> create(BusinessModel value) async {
    final box = HiveDatabase.instance.businessesBox;
    final id = value.id.isEmpty ? newBusinessId() : value.id;
    final now = DateTime.now().toIso8601String();
    final map = value.toMap()
      ..['id'] = id
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await box.put(id, map);
    return id;
  }

  Future<String> createWithUserSelection(BusinessModel value) async {
    final box = HiveDatabase.instance.businessesBox;
    final id = value.id.isEmpty ? newBusinessId() : value.id;
    final now = DateTime.now().toIso8601String();
    final map = value.toMap()
      ..['id'] = id
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await box.put(id, map);

    final userBox = HiveDatabase.instance.usersBox;
    final user = Map<String, dynamic>.from(userBox.get(value.ownerId) ?? <String, dynamic>{});
    user['id'] = value.ownerId;
    user['selectedBusinessId'] = id;
    user['name'] = user['name'] ?? value.ownerName;
    user['phone'] = user['phone'] ?? value.phone;
    user['currency'] = value.currency;
    user['updatedAt'] = now;
    await userBox.put(value.ownerId, user);

    return id;
  }

  Future<void> updateLogo(String businessId, String logoUrl) async {
    final box = HiveDatabase.instance.businessesBox;
    final data = box.get(businessId);
    if (data != null) {
      final updated = Map<String, dynamic>.from(data);
      updated['logoUrl'] = logoUrl;
      updated['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(businessId, updated);
    }
  }

  Future<void> updateEditable(BusinessModel business) async {
    final box = HiveDatabase.instance.businessesBox;
    final data = box.get(business.id);
    if (data == null) throw StateError('Business was not found.');
    final map = Map<String, dynamic>.from(data);
    if (map['ownerId'] != business.ownerId) {
      throw StateError('You do not have permission to edit this business.');
    }
    map['ownerName'] = business.ownerName.trim();
    map['businessName'] = business.businessName.trim();
    map['businessType'] = business.businessType.trim();
    map['phone'] = business.phone.trim();
    map['address'] = business.address.trim();
    map['city'] = business.city.trim();
    map['currency'] = business.currency.trim();
    map['logoUrl'] = business.logoUrl;
    map['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(business.id, map);
  }
}
