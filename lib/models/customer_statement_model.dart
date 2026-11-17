import 'transaction_model.dart';

class StatementBusiness {
  const StatementBusiness({
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.city,
    required this.logoUrl,
    required this.currency,
  });
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String city;
  final String logoUrl;
  final String currency;
}

class StatementCustomer {
  const StatementCustomer({
    required this.name,
    required this.phone,
    required this.address,
  });
  final String name;
  final String phone;
  final String address;
}

class CustomerStatementModel {
  const CustomerStatementModel({
    required this.customerId,
    required this.startDate,
    required this.endDate,
    required this.business,
    required this.customer,
    required this.openingBalance,
    required this.transactions,
    required this.totalGave,
    required this.totalReceived,
    required this.closingBalance,
  });
  final String customerId;
  final DateTime startDate;
  final DateTime endDate;
  final StatementBusiness business;
  final StatementCustomer customer;
  final double openingBalance;
  final List<TransactionModel> transactions;
  final double totalGave;
  final double totalReceived;
  final double closingBalance;
}
