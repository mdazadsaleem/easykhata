import '../core/database/hive_database.dart';
import '../models/customer_statement_model.dart';
import '../models/transaction_model.dart';

class CustomerStatementRepository {
  CustomerStatementRepository();

  Future<CustomerStatementModel> load({
    required String ownerId,
    required String businessId,
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bizData = HiveDatabase.instance.businessesBox.get(businessId);
    final custData = HiveDatabase.instance.customersBox.get(customerId);
    if (bizData == null) {
      throw StateError('Business not found.');
    }
    if (custData == null) {
      throw StateError('Customer not found.');
    }

    final businessData = Map<String, dynamic>.from(bizData);
    final customerData = Map<String, dynamic>.from(custData);

    final allTransactions = HiveDatabase.instance.transactionsBox.values
        .map((e) =>
            TransactionModel.fromMap(Map<String, dynamic>.from(e), e['id']))
        .where((t) =>
            t.ownerId == ownerId &&
            t.businessId == businessId &&
            t.customerId == customerId)
        .toList()
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    var opening = 0.0;
    for (final transaction in allTransactions.where(
      (item) => item.transactionDate.isBefore(startDate),
    )) {
      opening += transaction.transactionType == 'gave'
          ? transaction.amount
          : -transaction.amount;
    }
    final endExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));
    final selected = allTransactions
        .where(
          (item) =>
              !item.transactionDate.isBefore(startDate) &&
              item.transactionDate.isBefore(endExclusive),
        )
        .toList();
    final gave = selected
        .where((item) => item.transactionType == 'gave')
        .fold<double>(0, (total, item) => total + item.amount);
    final received = selected
        .where((item) => item.transactionType != 'gave')
        .fold<double>(0, (total, item) => total + item.amount);

    return CustomerStatementModel(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      business: StatementBusiness(
        name: businessData['businessName'] ?? '',
        ownerName: businessData['ownerName'] ?? '',
        phone: businessData['phone'] ?? '',
        address: businessData['address'] ?? '',
        city: businessData['city'] ?? '',
        logoUrl: businessData['logoUrl'] ?? '',
        currency: businessData['currency'] ?? 'PKR',
      ),
      customer: StatementCustomer(
        name: customerData['name'] ?? '',
        phone: customerData['phone'] ?? '',
        address: customerData['address'] ?? '',
      ),
      openingBalance: opening,
      transactions: selected,
      totalGave: gave,
      totalReceived: received,
      closingBalance: opening + gave - received,
    );
  }
}
