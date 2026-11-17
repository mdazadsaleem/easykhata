import '../core/database/hive_database.dart';
import '../models/transaction_model.dart';
import 'search_repository.dart';

class TransactionRepository {
  TransactionRepository();

  Stream<List<TransactionModel>> watchBusiness(
    String ownerId,
    String businessId,
  ) {
    final box = HiveDatabase.instance.transactionsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final transactions = box.values
            .map((e) =>
                TransactionModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((t) => t.ownerId == ownerId && t.businessId == businessId)
            .toList();
        transactions.sort(
          (first, second) =>
              second.transactionDate.compareTo(first.transactionDate),
        );
        controller.add(transactions);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<TransactionModel?> watchById({
    required String transactionId,
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.transactionsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final data = box.get(transactionId);
        if (data == null) {
          controller.add(null);
          return;
        }
        final tx =
            TransactionModel.fromMap(Map<String, dynamic>.from(data), transactionId);
        if (tx.ownerId != ownerId || tx.businessId != businessId) {
          controller.addError(
            StateError('You do not have permission to view this transaction.'),
          );
          return;
        }
        controller.add(tx);
      }

      emit();
      final sub = box.watch(key: transactionId).listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<List<TransactionModel>> watchCustomer(
    String ownerId,
    String businessId,
    String customerId,
  ) {
    final box = HiveDatabase.instance.transactionsBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final transactions = box.values
            .map((e) =>
                TransactionModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((t) =>
                t.ownerId == ownerId &&
                t.businessId == businessId &&
                t.customerId == customerId)
            .toList();
        transactions.sort(
          (first, second) =>
              second.transactionDate.compareTo(first.transactionDate),
        );
        controller.add(transactions);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<void> create(TransactionModel value) async {
    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;

    final customerData = custBox.get(value.customerId);
    if (customerData == null) throw StateError('Customer no longer exists.');
    final customer = Map<String, dynamic>.from(customerData);

    final old = (customer['currentBalance'] as num? ?? 0).toDouble();
    final delta =
        value.transactionType == 'gave' ? value.amount : -value.amount;
    final next = old + delta;
    final receivableChange = (next > 0 ? next : 0) - (old > 0 ? old : 0);
    final payableChange = (next < 0 ? -next : 0) - (old < 0 ? -old : 0);

    final txId = value.id.isNotEmpty
        ? value.id
        : 'tx_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final txMap = value.toMap()
      ..['id'] = txId
      ..['previousBalance'] = old
      ..['updatedBalance'] = next
      ..['newBalance'] = next
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await txBox.put(txId, txMap);

    customer['currentBalance'] = next;
    customer['lastTransactionAt'] = value.transactionDate.toIso8601String();
    customer['updatedAt'] = now;
    await custBox.put(value.customerId, customer);

    final bizData = bizBox.get(value.businessId);
    if (bizData != null) {
      final biz = Map<String, dynamic>.from(bizData);
      biz['totalReceivable'] =
          (biz['totalReceivable'] as num? ?? 0).toDouble() + receivableChange;
      biz['totalPayable'] =
          (biz['totalPayable'] as num? ?? 0).toDouble() + payableChange;
      biz['updatedAt'] = now;
      await bizBox.put(value.businessId, biz);
    }
  }

  Future<TransactionModel> createAtomic({
    required TransactionModel value,
    required String customerName,
    DateTime? reminderDate,
  }) async {
    if (!value.amount.isFinite || value.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }

    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;
    final remBox = HiveDatabase.instance.remindersBox;

    final customerData = custBox.get(value.customerId);
    final bizData = bizBox.get(value.businessId);
    if (customerData == null || bizData == null) {
      throw StateError('The customer or business no longer exists.');
    }

    final customer = Map<String, dynamic>.from(customerData);
    final biz = Map<String, dynamic>.from(bizData);

    final previousBalance =
        (customer['currentBalance'] as num? ?? 0).toDouble();
    final effect =
        value.transactionType == 'gave' ? value.amount : -value.amount;
    final newBalance = previousBalance + effect;
    final receivableChange =
        (newBalance > 0 ? newBalance : 0) -
        (previousBalance > 0 ? previousBalance : 0);
    final payableChange =
        (newBalance < 0 ? -newBalance : 0) -
        (previousBalance < 0 ? -previousBalance : 0);

    final txId = value.id.isNotEmpty
        ? value.id
        : 'tx_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final txMap = value.toMap()
      ..['id'] = txId
      ..['customerName'] = customerName
      ..['customerNameNormalized'] = normalizeSearchText(customerName)
      ..['descriptionNormalized'] = normalizeSearchText(value.description)
      ..['type'] = value.transactionType
      ..['previousBalance'] = previousBalance
      ..['newBalance'] = newBalance
      ..['updatedBalance'] = newBalance
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await txBox.put(txId, txMap);

    customer['currentBalance'] = newBalance;
    customer['lastTransactionAt'] = value.transactionDate.toIso8601String();
    customer['updatedAt'] = now;
    await custBox.put(value.customerId, customer);

    biz['totalReceivable'] =
        (biz['totalReceivable'] as num? ?? 0).toDouble() + receivableChange;
    biz['totalPayable'] =
        (biz['totalPayable'] as num? ?? 0).toDouble() + payableChange;
    biz['updatedAt'] = now;
    await bizBox.put(value.businessId, biz);

    if (reminderDate != null) {
      final remId = 'rem_${DateTime.now().microsecondsSinceEpoch}';
      final remMap = {
        'id': remId,
        'ownerId': value.ownerId,
        'businessId': value.businessId,
        'customerId': value.customerId,
        'customerName': customerName,
        'customerPhone': customer['phone'] ?? '',
        'amount': value.amount,
        'message':
            'Payment reminder for ${value.description.trim().isEmpty ? 'ledger transaction' : value.description.trim()}',
        'dueDate': reminderDate.toIso8601String(),
        'status': 'pending',
        'notificationId': remId.hashCode & 0x7fffffff,
        'createdAt': now,
        'updatedAt': now,
      };
      await remBox.put(remId, remMap);
    }

    return TransactionModel(
      id: txId,
      ownerId: value.ownerId,
      businessId: value.businessId,
      customerId: value.customerId,
      transactionType: value.transactionType,
      amount: value.amount,
      description: value.description,
      receiptUrl: value.receiptUrl,
      previousBalance: previousBalance,
      updatedBalance: newBalance,
      paymentMethod: value.paymentMethod,
      transactionDate: value.transactionDate,
    );
  }

  Future<void> delete(TransactionModel value) async {
    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;

    final customerData = custBox.get(value.customerId);
    final txData = txBox.get(value.id);
    if (customerData == null || txData == null) {
      throw StateError('The transaction or customer no longer exists.');
    }

    final customer = Map<String, dynamic>.from(customerData);
    final saved =
        TransactionModel.fromMap(Map<String, dynamic>.from(txData), value.id);
    final oldBalance = (customer['currentBalance'] as num? ?? 0).toDouble();
    final effect =
        saved.transactionType == 'gave' ? saved.amount : -saved.amount;
    final newBalance = oldBalance - effect;
    final receivableChange =
        (newBalance > 0 ? newBalance : 0) - (oldBalance > 0 ? oldBalance : 0);
    final payableChange =
        (newBalance < 0 ? -newBalance : 0) - (oldBalance < 0 ? -oldBalance : 0);

    await txBox.delete(value.id);

    final now = DateTime.now().toIso8601String();
    customer['currentBalance'] = newBalance;
    customer['updatedAt'] = now;
    await custBox.put(value.customerId, customer);

    final bizData = bizBox.get(value.businessId);
    if (bizData != null) {
      final biz = Map<String, dynamic>.from(bizData);
      biz['totalReceivable'] =
          (biz['totalReceivable'] as num? ?? 0).toDouble() + receivableChange;
      biz['totalPayable'] =
          (biz['totalPayable'] as num? ?? 0).toDouble() + payableChange;
      biz['updatedAt'] = now;
      await bizBox.put(value.businessId, biz);
    }
  }

  Future<TransactionModel> updateEditable({
    required TransactionModel original,
    required double amount,
    required String description,
  }) async {
    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;

    final txData = txBox.get(original.id);
    final customerData = custBox.get(original.customerId);
    if (txData == null || customerData == null) {
      throw StateError('The transaction or customer no longer exists.');
    }

    final saved =
        TransactionModel.fromMap(Map<String, dynamic>.from(txData), original.id);
    final customer = Map<String, dynamic>.from(customerData);
    final oldCustomerBalance =
        (customer['currentBalance'] as num? ?? 0).toDouble();

    final oldEffect =
        saved.transactionType == 'gave' ? saved.amount : -saved.amount;
    final newEffect = saved.transactionType == 'gave' ? amount : -amount;
    final newBalance = oldCustomerBalance - oldEffect + newEffect;
    final transactionNewBalance = saved.previousBalance + newEffect;
    final receivableChange =
        (newBalance > 0 ? newBalance : 0) -
        (oldCustomerBalance > 0 ? oldCustomerBalance : 0);
    final payableChange =
        (newBalance < 0 ? -newBalance : 0) -
        (oldCustomerBalance < 0 ? -oldCustomerBalance : 0);

    final now = DateTime.now().toIso8601String();
    final updatedTx = Map<String, dynamic>.from(txData);
    updatedTx['amount'] = amount;
    updatedTx['description'] = description.trim();
    updatedTx['descriptionNormalized'] = normalizeSearchText(description);
    updatedTx['newBalance'] = transactionNewBalance;
    updatedTx['updatedBalance'] = transactionNewBalance;
    updatedTx['updatedAt'] = now;
    await txBox.put(original.id, updatedTx);

    customer['currentBalance'] = newBalance;
    customer['updatedAt'] = now;
    await custBox.put(original.customerId, customer);

    final bizData = bizBox.get(original.businessId);
    if (bizData != null) {
      final biz = Map<String, dynamic>.from(bizData);
      biz['totalReceivable'] =
          (biz['totalReceivable'] as num? ?? 0).toDouble() + receivableChange;
      biz['totalPayable'] =
          (biz['totalPayable'] as num? ?? 0).toDouble() + payableChange;
      biz['updatedAt'] = now;
      await bizBox.put(original.businessId, biz);
    }

    return original.copyWith(amount: amount, description: description);
  }

  Future<TransactionModel> updateAtomic(TransactionModel edited) async {
    if (!edited.amount.isFinite || edited.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }

    final custBox = HiveDatabase.instance.customersBox;
    final bizBox = HiveDatabase.instance.businessesBox;
    final txBox = HiveDatabase.instance.transactionsBox;

    final txData = txBox.get(edited.id);
    final customerData = custBox.get(edited.customerId);
    if (txData == null || customerData == null) {
      throw StateError('This transaction or customer no longer exists.');
    }

    final saved =
        TransactionModel.fromMap(Map<String, dynamic>.from(txData), edited.id);
    final customer = Map<String, dynamic>.from(customerData);
    final currentBalance =
        (customer['currentBalance'] as num? ?? 0).toDouble();

    final oldEffect =
        saved.transactionType == 'gave' ? saved.amount : -saved.amount;
    final balanceAfterReversal = currentBalance - oldEffect;
    final newEffect =
        edited.transactionType == 'gave' ? edited.amount : -edited.amount;
    final customerNewBalance = balanceAfterReversal + newEffect;
    final savedPreviousBalance = saved.previousBalance;
    final transactionNewBalance = saved.previousBalance + newEffect;
    final receivableChange =
        (customerNewBalance > 0 ? customerNewBalance : 0) -
        (currentBalance > 0 ? currentBalance : 0);
    final payableChange =
        (customerNewBalance < 0 ? -customerNewBalance : 0) -
        (currentBalance < 0 ? -currentBalance : 0);

    final now = DateTime.now().toIso8601String();
    final updatedTx = Map<String, dynamic>.from(txData);
    updatedTx['transactionType'] = edited.transactionType;
    updatedTx['type'] = edited.transactionType;
    updatedTx['amount'] = edited.amount;
    updatedTx['description'] = edited.description.trim();
    updatedTx['descriptionNormalized'] = normalizeSearchText(edited.description);
    updatedTx['paymentMethod'] = edited.paymentMethod;
    updatedTx['receiptUrl'] = edited.receiptUrl;
    updatedTx['transactionDate'] = edited.transactionDate.toIso8601String();
    updatedTx['previousBalance'] = saved.previousBalance;
    updatedTx['newBalance'] = transactionNewBalance;
    updatedTx['updatedBalance'] = transactionNewBalance;
    updatedTx['updatedAt'] = now;
    await txBox.put(edited.id, updatedTx);

    customer['currentBalance'] = customerNewBalance;
    customer['lastTransactionAt'] = edited.transactionDate.toIso8601String();
    customer['updatedAt'] = now;
    await custBox.put(edited.customerId, customer);

    final bizData = bizBox.get(edited.businessId);
    if (bizData != null) {
      final biz = Map<String, dynamic>.from(bizData);
      biz['totalReceivable'] =
          (biz['totalReceivable'] as num? ?? 0).toDouble() + receivableChange;
      biz['totalPayable'] =
          (biz['totalPayable'] as num? ?? 0).toDouble() + payableChange;
      biz['updatedAt'] = now;
      await bizBox.put(edited.businessId, biz);
    }

    return edited.copyWith(
      previousBalance: savedPreviousBalance,
      updatedBalance: transactionNewBalance,
    );
  }
}
