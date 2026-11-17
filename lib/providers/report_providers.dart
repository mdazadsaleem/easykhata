import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum ReportPeriod { today, week, month, year, custom }

class ReportFilter {
  const ReportFilter({this.period = ReportPeriod.month, this.customRange});
  final ReportPeriod period;
  final DateTimeRange? customRange;
}

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();
  void select(ReportPeriod period, [DateTimeRange? range]) =>
      state = ReportFilter(period: period, customRange: range);
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(
      ReportFilterNotifier.new,
    );

final reportRangeProvider = Provider<ReportRange>((ref) {
  final filter = ref.watch(reportFilterProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter.period) {
    ReportPeriod.today => ReportRange(
      start: today,
      end: today.add(const Duration(days: 1)),
    ),
    ReportPeriod.week => ReportRange(
      start: today.subtract(Duration(days: now.weekday - 1)),
      end: today
          .subtract(Duration(days: now.weekday - 1))
          .add(const Duration(days: 7)),
    ),
    ReportPeriod.month => ReportRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1),
    ),
    ReportPeriod.year => ReportRange(
      start: DateTime(now.year),
      end: DateTime(now.year + 1),
    ),
    ReportPeriod.custom => ReportRange(
      start: filter.customRange?.start ?? today,
      end: filter.customRange == null
          ? today.add(const Duration(days: 1))
          : DateTime(
              filter.customRange!.end.year,
              filter.customRange!.end.month,
              filter.customRange!.end.day,
            ).add(const Duration(days: 1)),
    ),
  };
});

final reportProvider = StreamProvider<ReportModel>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null || business.ownerId != user.uid) return;
  final range = ref.watch(reportRangeProvider);
  yield* ref
      .watch(reportRepositoryProvider)
      .watch(ownerId: user.uid, businessId: business.id, range: range);
});
