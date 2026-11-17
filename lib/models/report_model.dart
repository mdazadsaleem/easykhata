class ReportRange {
  const ReportRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.month,
    required this.cashIn,
    required this.cashOut,
  });
  final DateTime month;
  final double cashIn;
  final double cashOut;
}

class ReportPartyBalance {
  const ReportPartyBalance({
    required this.id,
    required this.name,
    required this.accountType,
    required this.balance,
  });
  final String id;
  final String name;
  final String accountType;
  final double balance;
}

class ReportModel {
  const ReportModel({
    required this.range,
    required this.totalReceivable,
    required this.totalPayable,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.monthlyCashFlow,
    required this.parties,
    required this.transactionCount,
    required this.cashEntryCount,
  });
  final ReportRange range;
  final double totalReceivable;
  final double totalPayable;
  final double totalCashIn;
  final double totalCashOut;
  final List<MonthlyCashFlowPoint> monthlyCashFlow;
  final List<ReportPartyBalance> parties;
  final int transactionCount;
  final int cashEntryCount;

  double get netCashFlow => totalCashIn - totalCashOut;
}
