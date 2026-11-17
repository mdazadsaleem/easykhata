import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/routes/app_routes.dart';
import '../../models/report_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/business_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/main_navigation_providers.dart';
import '../../providers/report_providers.dart';

const _blue = Color(0xFF173EB5);
const _green = Color(0xFF00A66A);
const _red = Color(0xFFE12D39);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD9DEEA);
const _page = Color(0xFFF8F9FD);

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (range != null) {
      ref
          .read(reportFilterProvider.notifier)
          .select(ReportPeriod.custom, range);
    }
  }

  Future<Uint8List> _pdf(
    ReportModel report,
    String businessName,
    String title,
  ) async {
    final document = pw.Document();
    final currency = intl.NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 2,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Smart Khata - $title',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(businessName),
          pw.Text(
            '${intl.DateFormat('dd MMM yyyy').format(report.range.start)} - '
            '${intl.DateFormat('dd MMM yyyy').format(report.range.end.subtract(const Duration(days: 1)))}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            data: [
              ['Total Receivable', currency.format(report.totalReceivable)],
              ['Total Payable', currency.format(report.totalPayable)],
              ['Total Cash In', currency.format(report.totalCashIn)],
              ['Total Cash Out', currency.format(report.totalCashOut)],
              ['Net Cash Flow', currency.format(report.netCashFlow)],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Party Balances',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Name', 'Type', 'Balance'],
            data: report.parties
                .where((party) => party.balance != 0)
                .map(
                  (party) => [
                    party.name,
                    party.accountType,
                    currency.format(party.balance),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> _reportAction(
    ReportModel report,
    String businessName, {
    required String title,
    bool share = false,
  }) async {
    final bytes = await _pdf(report, businessName, title);
    final fileName = '${title.replaceAll(' ', '_').toLowerCase()}.pdf';
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider).value;
    final user = ref.watch(currentUserProvider);
    final reportAsync = ref.watch(reportProvider);
    if (reportAsync.isLoading && !reportAsync.hasValue) {
      return const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    if (reportAsync.hasError || !reportAsync.hasValue) {
      return _ReportError(onRetry: () => ref.invalidate(reportProvider));
    }
    final report = reportAsync.requireValue;
    final filter = ref.watch(reportFilterProvider);
    final receivable = report.totalReceivable;
    final payable = report.totalPayable;
    final received = report.totalCashIn;
    final paid = report.totalCashOut;
    final cashFlow = report.monthlyCashFlow
        .map(
          (point) => MonthFlow(
            intl.DateFormat('MMM').format(point.month),
            point.cashIn,
            point.cashOut,
          ),
        )
        .toList();
    final totalOutstanding = receivable + payable;
    final receivableRatio = totalOutstanding == 0
        ? 0.0
        : receivable / totalOutstanding;
    final incomeExpenseTotal = math.max(received + paid, 1);

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentBusinessProvider);
            ref.invalidate(reportProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 24),
            children: [
              _Header(
                userName: user?.displayName ?? business?.ownerName ?? 'User',
                businessName: business?.businessName ?? 'Smart Khata',
                photoUrl: user?.photoURL,
                onPdf: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Financial Report',
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Financial Reports',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyze for the period of ${_periodLabel(filter.period)}',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final period in ReportPeriod.values) ...[
                      SizedBox(
                        width: 88,
                        child: _PeriodChip(
                          label: _periodLabel(period),
                          selected: filter.period == period,
                          onTap: () => period == ReportPeriod.custom
                              ? _selectCustomRange()
                              : ref
                                    .read(reportFilterProvider.notifier)
                                    .select(period),
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.68,
                children: [
                  _MetricCard(
                    label: 'Total Cash In',
                    amount: received,
                    detail: '${report.cashEntryCount} Cash Entries',
                    color: _green,
                    icon: Icons.south_west_rounded,
                  ),
                  _MetricCard(
                    label: 'Total Cash Out',
                    amount: paid,
                    detail: '${report.cashEntryCount} Cash Entries',
                    color: _red,
                    icon: Icons.north_east_rounded,
                  ),
                  _MetricCard(
                    label: 'Total Receivable',
                    amount: receivable,
                    detail:
                        'From ${report.parties.where((p) => p.balance > 0).length} Customers',
                    color: _blue,
                    icon: Icons.people_outline_rounded,
                  ),
                  _MetricCard(
                    label: 'Total Payable',
                    amount: payable,
                    detail:
                        'To ${report.parties.where((p) => p.balance < 0).length} Suppliers',
                    color: const Color(0xFF6941C6),
                    icon: Icons.storefront_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _NetCashCard(value: report.netCashFlow),
              const SizedBox(height: 14),
              _ReportCard(
                title: 'Monthly Cash Flow',
                trailing: const Icon(
                  Icons.calendar_month_outlined,
                  size: 17,
                  color: _muted,
                ),
                child: SizedBox(
                  height: 155,
                  child: _CashFlowChart(data: cashFlow),
                ),
              ),
              const SizedBox(height: 11),
              _ReportCard(
                title: 'Outstanding Risk',
                trailing: const Icon(
                  Icons.more_vert_rounded,
                  size: 17,
                  color: _muted,
                ),
                child: _RiskContent(
                  receivableRatio: receivableRatio,
                  receivable: receivable,
                  payable: payable,
                ),
              ),
              const SizedBox(height: 11),
              _ReportCard(
                title: 'Income vs Expense Comparison',
                child: _ComparisonContent(
                  received: received,
                  paid: paid,
                  receivedRatio: received / incomeExpenseTotal,
                  paidRatio: paid / incomeExpenseTotal,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Specific Reports',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _ReportLinks(
                onCustomerStatement: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Customer Statement',
                ),
                onSupplierStatement: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Supplier Statement',
                ),
                onCashbook: () =>
                    ref.read(mainNavigationIndexProvider.notifier).select(2),
                onReceivable: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Receivable Report',
                ),
                onPayable: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Payable Report',
                ),
                onTax: () => _reportAction(
                  report,
                  business?.businessName ?? 'Smart Khata',
                  title: 'Monthly Business Summary',
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'shareReports',
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: () => _reportAction(
          report,
          business?.businessName ?? 'Smart Khata',
          title: 'Financial Report',
          share: true,
        ),
        child: const Icon(Icons.share_outlined, size: 19),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.businessName,
    required this.photoUrl,
    required this.onPdf,
  });
  final String userName;
  final String businessName;
  final String? photoUrl;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFE6ECFF),
        backgroundImage: photoUrl == null || photoUrl!.isEmpty
            ? null
            : NetworkImage(photoUrl!),
        child: photoUrl == null || photoUrl!.isEmpty
            ? const Icon(Icons.person_outline, size: 19, color: _blue)
            : null,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              businessName,
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 8),
            ),
          ],
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => context.push(AppRoutes.notifications),
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: _blue,
          size: 20,
        ),
      ),
      OutlinedButton.icon(
        onPressed: onPdf,
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 34),
          side: const BorderSide(color: _blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
        label: const Text(
          'Generate PDF',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _blue : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: selected ? _blue : _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.detail,
    required this.color,
    required this.icon,
  });
  final String label;
  final double amount;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09000000),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          _money(amount),
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: _muted, fontSize: 7)),
      ],
    ),
  );
}

class _NetCashCard extends StatelessWidget {
  const _NetCashCard({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: _blue,
      borderRadius: BorderRadius.circular(7),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30173EB5),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NET CASH FLOW',
          style: TextStyle(
            color: Color(0xFFC8D4FF),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _money(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'Money received minus money paid',
          style: TextStyle(color: Color(0xFFC8D4FF), fontSize: 7),
        ),
      ],
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.data});
  final List<MonthFlow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty ||
        data.every((point) => point.received == 0 && point.paid == 0)) {
      return const Center(
        child: Text(
          'No cash flow data for this period',
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      );
    }
    final maxY = math.max(
      1,
      data.fold<double>(
        0,
        (value, item) => math.max(value, math.max(item.received, item.paid)),
      ),
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    data[index].label,
                    style: const TextStyle(fontSize: 7, color: _muted),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < data.length; index++)
                FlSpot(index.toDouble(), data[index].received),
            ],
            color: _green,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [
              for (var index = 0; index < data.length; index++)
                FlSpot(index.toDouble(), data[index].paid),
            ],
            color: _red,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class CashFlowPainterLegacy extends CustomPainter {
  CashFlowPainterLegacy(this.data);
  final List<MonthFlow> data;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 20.0;
    const bottom = 22.0;
    const top = 8.0;
    final plotHeight = size.height - bottom - top;
    final plotWidth = size.width - left - 5;
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EBF2)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = top + plotHeight * row / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }
    final maxValue = math.max(
      data.fold<double>(
        0,
        (max, item) => math.max(max, math.max(item.received, item.paid)),
      ),
      1,
    );
    Offset point(int index, double value) => Offset(
      left + plotWidth * index / math.max(data.length - 1, 1),
      top + plotHeight * (1 - value / maxValue),
    );
    void drawSeries(Color color, double Function(MonthFlow) value) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final p = point(i, value(data[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
      final dot = Paint()..color = color;
      for (var i = 0; i < data.length; i++) {
        canvas.drawCircle(point(i, value(data[i])), 2.5, dot);
      }
    }

    drawSeries(_green, (item) => item.received);
    drawSeries(_blue, (item) => item.paid);
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < data.length; i++) {
      label.text = TextSpan(
        text: data[i].label,
        style: const TextStyle(fontSize: 7, color: _muted),
      );
      label.layout();
      final x = left + plotWidth * i / math.max(data.length - 1, 1);
      label.paint(canvas, Offset(x - label.width / 2, size.height - 13));
    }
  }

  @override
  bool shouldRepaint(covariant CashFlowPainterLegacy oldDelegate) =>
      oldDelegate.data != data;
}

class _RiskContent extends StatelessWidget {
  const _RiskContent({
    required this.receivableRatio,
    required this.receivable,
    required this.payable,
  });
  final double receivableRatio;
  final double receivable;
  final double payable;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 105,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 88,
              child: CircularProgressIndicator(
                value: receivableRatio,
                strokeWidth: 13,
                backgroundColor: _red,
                color: _green,
              ),
            ),
            Text(
              '${(receivableRatio * 100).round()}%',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      Row(
        children: [
          Expanded(
            child: _Legend(
              color: _green,
              label: 'Receivable',
              value: _money(receivable),
            ),
          ),
          Expanded(
            child: _Legend(
              color: _red,
              label: 'Payable',
              value: _money(payable),
              alignEnd: true,
            ),
          ),
        ],
      ),
    ],
  );
}

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({
    required this.received,
    required this.paid,
    required this.receivedRatio,
    required this.paidRatio,
  });
  final double received;
  final double paid;
  final double receivedRatio;
  final double paidRatio;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ComparisonBar(
        label: 'Income',
        value: received,
        ratio: receivedRatio,
        color: _blue,
      ),
      const SizedBox(height: 14),
      _ComparisonBar(
        label: 'Expense',
        value: paid,
        ratio: paidRatio,
        color: const Color(0xFF6941C6),
      ),
    ],
  );
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });
  final String label;
  final double value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 9))),
          Text(
            _money(value),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          backgroundColor: const Color(0xFFEDF0F6),
          color: color,
        ),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });
  final Color color;
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ReportLinks extends StatelessWidget {
  const _ReportLinks({
    required this.onCustomerStatement,
    required this.onSupplierStatement,
    required this.onCashbook,
    required this.onReceivable,
    required this.onPayable,
    required this.onTax,
  });
  final VoidCallback onCustomerStatement;
  final VoidCallback onSupplierStatement;
  final VoidCallback onCashbook;
  final VoidCallback onReceivable;
  final VoidCallback onPayable;
  final VoidCallback onTax;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        _ReportLink(
          icon: Icons.description_outlined,
          title: 'Customer Statement',
          subtitle: 'Ledger details for specific clients',
          onTap: onCustomerStatement,
        ),
        _ReportLink(
          icon: Icons.receipt_long_outlined,
          title: 'Supplier Statement',
          subtitle: 'Payables and purchase history',
          onTap: onSupplierStatement,
        ),
        _ReportLink(
          icon: Icons.call_received_outlined,
          title: 'Receivable Report',
          subtitle: 'All outstanding customer balances',
          onTap: onReceivable,
        ),
        _ReportLink(
          icon: Icons.call_made_outlined,
          title: 'Payable Report',
          subtitle: 'All outstanding supplier balances',
          onTap: onPayable,
        ),
        _ReportLink(
          icon: Icons.menu_book_outlined,
          title: 'Cashbook Report',
          subtitle: 'Detailed daily cash flow register',
          onTap: onCashbook,
        ),
        _ReportLink(
          icon: Icons.account_balance_outlined,
          title: 'Monthly Business Summary',
          subtitle: 'Complete monthly financial summary',
          onTap: onTax,
          divider: false,
        ),
      ],
    ),
  );
}

class _ReportLink extends StatelessWidget {
  const _ReportLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.divider = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        onTap: onTap,
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, color: _blue, size: 15),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 7, color: _muted),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 17,
          color: _muted,
        ),
      ),
      if (divider)
        const Divider(height: 1, indent: 48, color: Color(0xFFE8EBF2)),
    ],
  );
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _page,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined, size: 48, color: _muted),
          const SizedBox(height: 12),
          const Text('Could not load financial reports.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class MonthFlow {
  const MonthFlow(this.label, this.received, this.paid);
  final String label;
  final double received;
  final double paid;
}

List<MonthFlow> monthlyCashFlowLegacy(List<TransactionModel> transactions) {
  final now = DateTime.now();
  return List.generate(6, (index) {
    final month = DateTime(now.year, now.month - 5 + index);
    final entries = transactions.where(
      (item) =>
          item.transactionDate.year == month.year &&
          item.transactionDate.month == month.month,
    );
    final received = entries
        .where(isReceivedLegacy)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final paid = entries
        .where((item) => !isReceivedLegacy(item))
        .fold<double>(0, (sum, item) => sum + item.amount);
    return MonthFlow(intl.DateFormat('MMM').format(month), received, paid);
  });
}

bool insidePeriodLegacy(DateTime date, ReportPeriod period) {
  final now = DateTime.now();
  return switch (period) {
    ReportPeriod.today =>
      date.year == now.year && date.month == now.month && date.day == now.day,
    ReportPeriod.week => !date.isBefore(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
    ),
    ReportPeriod.month => date.year == now.year && date.month == now.month,
    ReportPeriod.year => date.year == now.year,
    ReportPeriod.custom => true,
  };
}

bool isReceivedLegacy(TransactionModel item) => item.transactionType != 'gave';

String _periodLabel(ReportPeriod period) => switch (period) {
  ReportPeriod.today => 'Today',
  ReportPeriod.week => 'This Week',
  ReportPeriod.month => 'This Month',
  ReportPeriod.year => 'This Year',
  ReportPeriod.custom => 'Custom',
};

String _money(double amount) => intl.NumberFormat.currency(
  locale: 'en_PK',
  symbol: 'PKR ',
  decimalDigits: 2,
).format(amount);

String legacyMoney(double amount) =>
    intl.NumberFormat.currency(symbol: '₨ ', decimalDigits: 2).format(amount);
