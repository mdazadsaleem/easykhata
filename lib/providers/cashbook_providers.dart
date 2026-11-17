import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cashbook_entry_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum CashbookPeriod { today, weekly, monthly, custom }

class CashbookFilter {
  const CashbookFilter({
    this.period = CashbookPeriod.today,
    this.customRange,
    this.category,
    this.paymentMethod,
    this.query = '',
  });
  final CashbookPeriod period;
  final DateTimeRange? customRange;
  final String? category;
  final String? paymentMethod;
  final String query;

  CashbookFilter copyWith({
    CashbookPeriod? period,
    DateTimeRange? customRange,
    bool clearRange = false,
    String? category,
    bool clearCategory = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    String? query,
  }) => CashbookFilter(
    period: period ?? this.period,
    customRange: clearRange ? null : customRange ?? this.customRange,
    category: clearCategory ? null : category ?? this.category,
    paymentMethod: clearPaymentMethod
        ? null
        : paymentMethod ?? this.paymentMethod,
    query: query ?? this.query,
  );
}

class CashbookFilterNotifier extends Notifier<CashbookFilter> {
  @override
  CashbookFilter build() => const CashbookFilter();
  void set(CashbookFilter value) => state = value;
  void search(String value) =>
      state = state.copyWith(query: value.trim().toLowerCase());
}

final cashbookFilterProvider =
    NotifierProvider<CashbookFilterNotifier, CashbookFilter>(
      CashbookFilterNotifier.new,
    );

final cashbookEntriesProvider = StreamProvider<List<CashbookEntryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return Stream.value([]);
  return ref.watch(cashbookRepositoryProvider).watch(user.uid, business.id);
});

class CashbookViewData {
  const CashbookViewData({
    required this.entries,
    required this.openingBalance,
    required this.cashIn,
    required this.cashOut,
    required this.closingBalance,
    required this.start,
    required this.end,
  });
  final List<CashbookEntryModel> entries;
  final double openingBalance;
  final double cashIn;
  final double cashOut;
  final double closingBalance;
  final DateTime start;
  final DateTime end;
}

final cashbookViewProvider = Provider<CashbookViewData>((ref) {
  final all = ref.watch(cashbookEntriesProvider).value ?? const [];
  final filter = ref.watch(cashbookFilterProvider);
  final now = DateTime.now();
  late DateTime start;
  late DateTime end;
  switch (filter.period) {
    case CashbookPeriod.today:
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
      break;
    case CashbookPeriod.weekly:
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      end = start.add(const Duration(days: 7));
      break;
    case CashbookPeriod.monthly:
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
      break;
    case CashbookPeriod.custom:
      final range = filter.customRange;
      start = range?.start ?? DateTime(now.year, now.month, now.day);
      end = range == null
          ? start.add(const Duration(days: 1))
          : DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
            ).add(const Duration(days: 1));
      break;
  }
  final opening = all
      .where((entry) => entry.entryDate.isBefore(start))
      .fold<double>(
        0,
        (sum, entry) => sum + (entry.isCashIn ? entry.amount : -entry.amount),
      );
  final inRange = all
      .where(
        (entry) =>
            !entry.entryDate.isBefore(start) && entry.entryDate.isBefore(end),
      )
      .toList();
  final cashIn = inRange
      .where((entry) => entry.isCashIn)
      .fold<double>(0, (sum, entry) => sum + entry.amount);
  final cashOut = inRange
      .where((entry) => !entry.isCashIn)
      .fold<double>(0, (sum, entry) => sum + entry.amount);
  final visible = inRange.where((entry) {
    final matchesCategory =
        filter.category == null || entry.category == filter.category;
    final matchesPayment =
        filter.paymentMethod == null ||
        entry.paymentMethod == filter.paymentMethod;
    final query = filter.query;
    final matchesSearch =
        query.isEmpty ||
        entry.category.toLowerCase().contains(query) ||
        entry.description.toLowerCase().contains(query) ||
        entry.paymentMethod.toLowerCase().contains(query) ||
        entry.amount.toString().contains(query);
    return matchesCategory && matchesPayment && matchesSearch;
  }).toList();
  return CashbookViewData(
    entries: visible,
    openingBalance: opening,
    cashIn: cashIn,
    cashOut: cashOut,
    closingBalance: opening + cashIn - cashOut,
    start: start,
    end: end,
  );
});

enum CashbookMutationStatus { idle, saving, deleting, success, error }

class CashbookMutationState {
  const CashbookMutationState({
    this.status = CashbookMutationStatus.idle,
    this.errorMessage,
  });
  final CashbookMutationStatus status;
  final String? errorMessage;
  bool get isLoading =>
      status == CashbookMutationStatus.saving ||
      status == CashbookMutationStatus.deleting;
}

final cashbookMutationProvider =
    NotifierProvider<CashbookMutationNotifier, CashbookMutationState>(
      CashbookMutationNotifier.new,
    );

class CashbookMutationNotifier extends Notifier<CashbookMutationState> {
  @override
  CashbookMutationState build() => const CashbookMutationState();

  Future<bool> save(CashbookEntryModel entry, {bool edit = false}) async {
    if (state.isLoading) return false;
    state = const CashbookMutationState(status: CashbookMutationStatus.saving);
    try {
      if (edit) {
        await ref.read(cashbookRepositoryProvider).update(entry);
      } else {
        await ref.read(cashbookRepositoryProvider).create(entry);
      }
      state = const CashbookMutationState(
        status: CashbookMutationStatus.success,
      );
      return true;
    } catch (_) {
      state = const CashbookMutationState(
        status: CashbookMutationStatus.error,
        errorMessage: 'Could not save this cash entry.',
      );
      return false;
    }
  }

  Future<bool> delete(CashbookEntryModel entry) async {
    if (state.isLoading) return false;
    state = const CashbookMutationState(
      status: CashbookMutationStatus.deleting,
    );
    try {
      await ref.read(cashbookRepositoryProvider).delete(entry);
      state = const CashbookMutationState(
        status: CashbookMutationStatus.success,
      );
      return true;
    } catch (_) {
      state = const CashbookMutationState(
        status: CashbookMutationStatus.error,
        errorMessage: 'Could not delete this cash entry.',
      );
      return false;
    }
  }
}
