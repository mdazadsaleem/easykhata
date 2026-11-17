import 'dart:async';

import '../core/database/hive_database.dart';
import '../models/report_model.dart';
import '../core/utils/date_helpers.dart';

class ReportRepository {
  ReportRepository();

  Stream<ReportModel> watch({
    required String ownerId,
    required String businessId,
    required ReportRange range,
  }) {
    late StreamController<ReportModel> controller;
    final subs = <StreamSubscription>[];

    void emit() {
      if (controller.isClosed) return;

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

      final cashEntries = HiveDatabase.instance.cashbookBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) => c['ownerId'] == ownerId && c['businessId'] == businessId)
          .toList();

      final balances = <String, double>{};
      for (final data in transactions) {
        final date = parseDate(data['transactionDate']);
        if (date == null || !date.isBefore(range.end)) continue;
        final customerId = data['customerId'] as String? ?? '';
        final type = data['transactionType'] ?? data['type'] ?? 'gave';
        final amount = _number(data['amount']);
        balances.update(
          customerId,
          (value) => value + (type == 'gave' ? amount : -amount),
          ifAbsent: () => type == 'gave' ? amount : -amount,
        );
      }

      final parties = customers.map((data) {
        final id = data['id'] as String? ?? '';
        var balance = balances[id];
        if (balance == null && range.end.isAfter(DateTime.now())) {
          balance = _number(data['currentBalance']);
        }
        return ReportPartyBalance(
          id: id,
          name: data['name'] ?? '',
          accountType: data['accountType'] ?? 'customer',
          balance: balance ?? 0,
        );
      }).toList();

      final receivable = parties
          .where((party) => party.balance > 0)
          .fold<double>(0, (total, party) => total + party.balance);
      final payable = parties
          .where((party) => party.balance < 0)
          .fold<double>(0, (total, party) => total + party.balance.abs());

      var cashIn = 0.0;
      var cashOut = 0.0;
      final monthly = <DateTime, List<double>>{};
      var cashEntryCount = 0;
      for (final data in cashEntries) {
        final date = parseDate(data['entryDate']);
        if (date == null ||
            date.isBefore(range.start) ||
            !date.isBefore(range.end)) {
          continue;
        }
        cashEntryCount++;
        final amount = _number(data['amount']);
        final isCashIn = data['type'] == 'cashIn';
        if (isCashIn) {
          cashIn += amount;
        } else {
          cashOut += amount;
        }
        final month = DateTime(date.year, date.month);
        final values = monthly.putIfAbsent(month, () => [0, 0]);
        values[isCashIn ? 0 : 1] += amount;
      }

      final monthlyPoints = monthly.entries
          .map(
            (entry) => MonthlyCashFlowPoint(
              month: entry.key,
              cashIn: entry.value[0],
              cashOut: entry.value[1],
            ),
          )
          .toList()
        ..sort((a, b) => a.month.compareTo(b.month));

      final transactionCount = transactions.where((data) {
        final date = parseDate(data['transactionDate']);
        return date != null &&
            !date.isBefore(range.start) &&
            date.isBefore(range.end);
      }).length;

      controller.add(
        ReportModel(
          range: range,
          totalReceivable: receivable,
          totalPayable: payable,
          totalCashIn: cashIn,
          totalCashOut: cashOut,
          monthlyCashFlow: monthlyPoints,
          parties: parties,
          transactionCount: transactionCount,
          cashEntryCount: cashEntryCount,
        ),
      );
    }

    controller = StreamController<ReportModel>(
      onListen: () {
        emit();
        subs.add(HiveDatabase.instance.customersBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.transactionsBox.watch().listen((_) => emit()));
        subs.add(HiveDatabase.instance.cashbookBox.watch().listen((_) => emit()));
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  static double _number(dynamic value) => (value as num? ?? 0).toDouble();
}
