import 'dart:async';

import '../core/database/hive_database.dart';
import '../models/dashboard_model.dart';
import '../core/utils/date_helpers.dart';

class DashboardRepository {
  DashboardRepository();

  Stream<DashboardModel> watch({
    required String ownerId,
    required String businessId,
  }) {
    late StreamController<DashboardModel> controller;
    final subs = <StreamSubscription>[];

    void emit() {
      if (controller.isClosed) return;

      final bizData = HiveDatabase.instance.businessesBox.get(businessId);
      final business = bizData != null
          ? Map<String, dynamic>.from(bizData)
          : <String, dynamic>{};

      final customers = HiveDatabase.instance.customersBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) =>
              c['ownerId'] == ownerId &&
              c['businessId'] == businessId &&
              c['isActive'] != false)
          .toList();

      final transactions = HiveDatabase.instance.transactionsBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((t) => t['ownerId'] == ownerId && t['businessId'] == businessId)
          .toList();

      final cashbook = HiveDatabase.instance.cashbookBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
          .toList();

      final reminders = HiveDatabase.instance.remindersBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((r) => r['ownerId'] == ownerId && r['businessId'] == businessId)
          .toList();

      final notifications = HiveDatabase.instance.notificationsBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((n) => n['ownerId'] == ownerId && n['businessId'] == businessId)
          .toList();

      final customerNames = <String, String>{
        for (final doc in customers)
          doc['id'] as String? ?? '': doc['name'] as String? ?? 'Customer',
      };

      final receivable = customers
          .map((doc) => _number(doc['currentBalance']))
          .where((balance) => balance > 0)
          .fold<double>(0, (total, balance) => total + balance);

      final payable = customers
          .map((doc) => _number(doc['currentBalance']))
          .where((balance) => balance < 0)
          .fold<double>(0, (total, balance) => total + balance.abs());

      final cashIn = cashbook
          .where((doc) => doc['type'] == 'cashIn')
          .fold<double>(
            0,
            (total, doc) => total + _number(doc['amount']),
          );

      final cashOut = cashbook
          .where((doc) => doc['type'] == 'cashOut')
          .fold<double>(
            0,
            (total, doc) => total + _number(doc['amount']),
          );

      final recent = transactions.map((data) {
        final customerId = data['customerId'] as String? ?? '';
        return DashboardTransaction(
          id: data['id'] as String? ?? '',
          customerId: customerId,
          customerName:
              data['customerName'] as String? ??
              customerNames[customerId] ??
              'Customer',
          type:
              data['type'] as String? ??
              data['transactionType'] as String? ??
              'gave',
          amount: _number(data['amount']),
          date: dashboardDate(data['transactionDate']),
          newBalance: _number(data['newBalance'] ?? data['updatedBalance']),
        );
      }).toList()..sort((first, second) => second.date.compareTo(first.date));

      final now = DateTime.now();
      final overdue = reminders.where((data) {
        final dueDate = parseDate(data['dueDate']);
        return data['status'] != 'completed' &&
            dueDate != null &&
            dueDate.isBefore(now);
      }).length;

      final unread = notifications.where((doc) => doc['isRead'] != true).length;

      controller.add(
        DashboardModel(
          ownerName: business['ownerName'] as String? ?? '',
          businessName: business['businessName'] as String? ?? 'Smart Khata',
          logoUrl: business['logoUrl'] as String? ?? '',
          currency: business['currency'] as String? ?? 'PKR',
          totalReceivable: receivable,
          totalPayable: payable,
          cashBalance: _number(business['cashBalance']),
          totalCashIn: cashIn,
          totalCashOut: cashOut,
          totalCustomers: customers
              .where((doc) => doc['accountType'] != 'supplier')
              .length,
          totalSuppliers: customers
              .where((doc) => doc['accountType'] == 'supplier')
              .length,
          overdueReminders: overdue,
          unreadNotifications: unread,
          recentTransactions: recent.take(15).toList(),
        ),
      );
    }

    controller = StreamController<DashboardModel>(
      onListen: () {
        emit();
        subs.add(HiveDatabase.instance.businessesBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.customersBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.transactionsBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.cashbookBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.remindersBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.notificationsBox.watch().listen((_) => emit()));
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}
