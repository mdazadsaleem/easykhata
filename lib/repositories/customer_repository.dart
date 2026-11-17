import '../core/database/hive_database.dart';
import '../models/customer_model.dart';
import 'search_repository.dart';

class CustomerRepository {
  CustomerRepository();

  Stream<List<CustomerModel>> watch(String ownerId, String businessId) {
    final box = HiveDatabase.instance.customersBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final customers = box.values
            .map((e) => CustomerModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((c) =>
                c.ownerId == ownerId &&
                c.businessId == businessId &&
                c.isActive)
            .toList();
        customers.sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
        controller.add(customers);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<CustomerModel?> watchById({
    required String customerId,
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.customersBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final data = box.get(customerId);
        if (data == null) {
          controller.add(null);
          return;
        }
        final customer =
            CustomerModel.fromMap(Map<String, dynamic>.from(data), customerId);
        if (customer.ownerId != ownerId || customer.businessId != businessId) {
          controller.addError(const CustomerPermissionException());
          return;
        }
        controller.add(customer);
      }

      emit();
      final sub = box.watch(key: customerId).listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<String> create(CustomerModel model) async {
    final box = HiveDatabase.instance.customersBox;
    final id = model.id.isNotEmpty
        ? model.id
        : 'cust_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    final map = model.copyWith(id: id).toMap()
      ..['nameNormalized'] = normalizeSearchText(model.name)
      ..['phoneNormalized'] = model.phone.replaceAll(RegExp(r'\D'), '')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await box.put(id, map);
    return id;
  }

  String customerIdFor(String businessId, String normalizedPhone) {
    final phoneDigits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return '${businessId}_$phoneDigits';
  }

  Future<bool> phoneExists({
    required String ownerId,
    required String businessId,
    required String normalizedPhone,
  }) async {
    final box = HiveDatabase.instance.customersBox;
    final normalizedDigits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return box.values.any((e) {
      final data = Map<String, dynamic>.from(e);
      if (data['ownerId'] != ownerId || data['businessId'] != businessId) {
        return false;
      }
      final savedPhone = (data['phoneNormalized'] ?? data['phone'] ?? '').toString();
      return savedPhone.replaceAll(RegExp(r'\D'), '') == normalizedDigits;
    });
  }

  Future<bool> phoneExistsForAnotherCustomer({
    required String ownerId,
    required String businessId,
    required String normalizedPhone,
    required String excludedCustomerId,
  }) async {
    final box = HiveDatabase.instance.customersBox;
    final normalizedDigits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return box.values.any((e) {
      final data = Map<String, dynamic>.from(e);
      if (data['id'] == excludedCustomerId) return false;
      if (data['ownerId'] != ownerId || data['businessId'] != businessId) {
        return false;
      }
      final phone = (data['phoneNormalized'] ?? data['phone'] ?? '').toString();
      return phone.replaceAll(RegExp(r'\D'), '') == normalizedDigits;
    });
  }

  Future<CustomerModel> updateEditable(CustomerModel customer) async {
    final box = HiveDatabase.instance.customersBox;
    final data = box.get(customer.id);
    if (data == null) throw const CustomerNotFoundException();
    final map = Map<String, dynamic>.from(data);
    if (map['ownerId'] != customer.ownerId ||
        map['businessId'] != customer.businessId) {
      throw const CustomerPermissionException();
    }
    map['name'] = customer.name;
    map['nameNormalized'] = normalizeSearchText(customer.name);
    map['phone'] = customer.phone;
    map['phoneNormalized'] = customer.phone.replaceAll(RegExp(r'\D'), '');
    map['address'] = customer.address;
    map['accountType'] = customer.accountType;
    map['notes'] = customer.notes;
    map['profileImage'] = customer.profileImage;
    map['profileImageUrl'] = customer.profileImage;
    map['updatedAt'] = DateTime.now().toIso8601String();
    await box.put(customer.id, map);
    return customer;
  }

  Future<bool> deleteSafely(CustomerModel customer) async {
    if (await hasTransactions(customer)) {
      await archive(customer.id);
      return false;
    }
    final box = HiveDatabase.instance.customersBox;
    await box.delete(customer.id);
    return true;
  }

  Future<CustomerModel> createWithOpeningBalance(CustomerModel customer) async {
    final normalizedPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (await phoneExists(
      ownerId: customer.ownerId,
      businessId: customer.businessId,
      normalizedPhone: customer.phone,
    )) {
      throw const CustomerAlreadyExistsException();
    }

    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;

    final customerId = customer.id.isNotEmpty
        ? customer.id
        : 'cust_${DateTime.now().microsecondsSinceEpoch}';

    final now = DateTime.now().toIso8601String();
    final hasOpeningBalance = customer.currentBalance != 0;

    final customerData = customer.copyWith(id: customerId).toMap()
      ..['nameNormalized'] = normalizeSearchText(customer.name)
      ..['phoneNormalized'] = normalizedPhone
      ..['createdAt'] = now
      ..['updatedAt'] = now
      ..['lastTransactionAt'] = hasOpeningBalance ? now : null;

    await custBox.put(customerId, customerData);

    if (hasOpeningBalance) {
      final amount = customer.currentBalance.abs();
      final txId = 'tx_${DateTime.now().microsecondsSinceEpoch}';
      final txData = {
        'id': txId,
        'ownerId': customer.ownerId,
        'businessId': customer.businessId,
        'customerId': customerId,
        'customerName': customer.name,
        'customerNameNormalized': normalizeSearchText(customer.name),
        'type': customer.currentBalance > 0 ? 'gave' : 'received',
        'amount': amount,
        'description': 'Opening Balance',
        'descriptionNormalized': 'opening balance',
        'paymentMethod': 'Opening Balance',
        'receiptUrl': '',
        'previousBalance': 0.0,
        'newBalance': customer.currentBalance,
        'updatedBalance': customer.currentBalance,
        'transactionDate': now,
        'createdAt': now,
        'updatedAt': now,
      };
      await txBox.put(txId, txData);

      final bizData = bizBox.get(customer.businessId);
      if (bizData != null) {
        final biz = Map<String, dynamic>.from(bizData);
        if (customer.currentBalance > 0) {
          biz['totalReceivable'] =
              (biz['totalReceivable'] as num? ?? 0).toDouble() + amount;
        } else {
          biz['totalPayable'] =
              (biz['totalPayable'] as num? ?? 0).toDouble() + amount;
        }
        biz['updatedAt'] = now;
        await bizBox.put(customer.businessId, biz);
      }
    }

    return customer.copyWith(id: customerId);
  }

  Future<void> update(CustomerModel model) async {
    final box = HiveDatabase.instance.customersBox;
    final data = box.get(model.id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['name'] = model.name;
      map['nameNormalized'] = normalizeSearchText(model.name);
      map['phone'] = model.phone;
      map['phoneNormalized'] = model.phone.replaceAll(RegExp(r'\D'), '');
      map['address'] = model.address;
      map['accountType'] = model.accountType;
      map['notes'] = model.notes;
      map['profileImage'] = model.profileImage;
      map['profileImageUrl'] = model.profileImage;
      map['isActive'] = model.isActive;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(model.id, map);
    }
  }

  Future<void> delete(String id) async {
    final box = HiveDatabase.instance.customersBox;
    await box.delete(id);
  }

  Future<bool> hasTransactions(CustomerModel customer) async {
    final txBox = HiveDatabase.instance.transactionsBox;
    return txBox.values.any((e) {
      final data = Map<String, dynamic>.from(e);
      return data['ownerId'] == customer.ownerId &&
          data['businessId'] == customer.businessId &&
          data['customerId'] == customer.id;
    });
  }

  Future<void> archive(String id) async {
    final box = HiveDatabase.instance.customersBox;
    final data = box.get(id);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['isActive'] = false;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(id, map);
    }
  }
}

class CustomerAlreadyExistsException implements Exception {
  const CustomerAlreadyExistsException();

  @override
  String toString() =>
      'A customer with this phone number already exists in this business.';
}

class CustomerNotFoundException implements Exception {
  const CustomerNotFoundException();
}

class CustomerPermissionException implements Exception {
  const CustomerPermissionException();

  @override
  String toString() => 'You do not have permission to access this customer.';
}
