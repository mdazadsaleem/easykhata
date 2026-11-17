import '../core/utils/date_helpers.dart';

class DashboardTransaction {
  const DashboardTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.amount,
    required this.date,
    required this.newBalance,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String type;
  final double amount;
  final DateTime date;
  final double newBalance;
}

class DashboardModel {
  const DashboardModel({
    required this.ownerName,
    required this.businessName,
    required this.logoUrl,
    required this.currency,
    required this.totalReceivable,
    required this.totalPayable,
    required this.cashBalance,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalCustomers,
    required this.totalSuppliers,
    required this.overdueReminders,
    required this.unreadNotifications,
    required this.recentTransactions,
  });

  final String ownerName;
  final String businessName;
  final String logoUrl;
  final String currency;
  final double totalReceivable;
  final double totalPayable;
  final double cashBalance;
  final double totalCashIn;
  final double totalCashOut;
  final int totalCustomers;
  final int totalSuppliers;
  final int overdueReminders;
  final int unreadNotifications;
  final List<DashboardTransaction> recentTransactions;
}

DateTime dashboardDate(dynamic value) => parseDate(value) ?? DateTime.now();
