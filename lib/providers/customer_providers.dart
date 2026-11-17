import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

enum CustomerTab { all, customers, suppliers, settled }

enum CustomerSort {
  name,
  highestBalance,
  lowestBalance,
  recentlyAdded,
  lastTransaction,
}

enum CustomerBalanceFilter { all, receivable, payable, settled }

class CustomerFilterState {
  const CustomerFilterState({
    this.search = '',
    this.tab = CustomerTab.all,
    this.sort = CustomerSort.name,
    this.balance = CustomerBalanceFilter.all,
  });

  final String search;
  final CustomerTab tab;
  final CustomerSort sort;
  final CustomerBalanceFilter balance;

  CustomerFilterState copyWith({
    String? search,
    CustomerTab? tab,
    CustomerSort? sort,
    CustomerBalanceFilter? balance,
  }) => CustomerFilterState(
    search: search ?? this.search,
    tab: tab ?? this.tab,
    sort: sort ?? this.sort,
    balance: balance ?? this.balance,
  );
}

final customerFiltersProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilterState>(
      CustomerFilterNotifier.new,
    );

class CustomerFilterNotifier extends Notifier<CustomerFilterState> {
  Timer? _debounce;

  @override
  CustomerFilterState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const CustomerFilterState();
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(search: value.trim().toLowerCase());
    });
  }

  void selectTab(CustomerTab value) => state = state.copyWith(tab: value);

  void selectSort(CustomerSort value) => state = state.copyWith(sort: value);

  void selectBalance(CustomerBalanceFilter value) =>
      state = state.copyWith(balance: value);
}

final customersProvider = StreamProvider<List<CustomerModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final business = ref.watch(currentBusinessProvider).value;
  if (user == null || business == null) return Stream.value([]);
  return ref.watch(customerRepositoryProvider).watch(user.uid, business.id);
});

final visibleCustomersProvider = Provider<AsyncValue<List<CustomerModel>>>((
  ref,
) {
  final filters = ref.watch(customerFiltersProvider);
  return ref.watch(customersProvider).whenData((customers) {
    final visible = customers.where((customer) {
      final matchesSearch =
          filters.search.isEmpty ||
          customer.name.toLowerCase().contains(filters.search) ||
          customer.phone
              .replaceAll(RegExp(r'\D'), '')
              .contains(filters.search.replaceAll(RegExp(r'\D'), ''));
      final matchesTab = switch (filters.tab) {
        CustomerTab.customers => customer.accountType == 'customer',
        CustomerTab.suppliers => customer.accountType == 'supplier',
        CustomerTab.settled => customer.currentBalance.abs() < .005,
        CustomerTab.all => true,
      };
      final matchesBalance = switch (filters.balance) {
        CustomerBalanceFilter.receivable => customer.currentBalance > .005,
        CustomerBalanceFilter.payable => customer.currentBalance < -.005,
        CustomerBalanceFilter.settled => customer.currentBalance.abs() < .005,
        CustomerBalanceFilter.all => true,
      };
      return matchesSearch && matchesTab && matchesBalance;
    }).toList();
    visible.sort(
      (first, second) => switch (filters.sort) {
        CustomerSort.name => first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        ),
        CustomerSort.highestBalance => second.currentBalance.abs().compareTo(
          first.currentBalance.abs(),
        ),
        CustomerSort.lowestBalance => first.currentBalance.abs().compareTo(
          second.currentBalance.abs(),
        ),
        CustomerSort.recentlyAdded =>
          (second.createdAt ?? DateTime(1970)).compareTo(
            first.createdAt ?? DateTime(1970),
          ),
        CustomerSort.lastTransaction =>
          (second.lastTransactionAt ?? DateTime(1970)).compareTo(
            first.lastTransactionAt ?? DateTime(1970),
          ),
      },
    );
    return visible;
  });
});

final customerBalanceSummaryProvider = Provider<(double, double)>((ref) {
  final customers = ref.watch(customersProvider).value ?? const [];
  final receive = customers
      .where((customer) => customer.currentBalance > 0)
      .fold<double>(0, (total, customer) => total + customer.currentBalance);
  final pay = customers
      .where((customer) => customer.currentBalance < 0)
      .fold<double>(
        0,
        (total, customer) => total + customer.currentBalance.abs(),
      );
  return (receive, pay);
});

final customerActionProvider =
    AsyncNotifierProvider<CustomerActionNotifier, void>(
      CustomerActionNotifier.new,
    );

class CustomerActionNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> hasTransactions(CustomerModel customer) =>
      ref.read(customerRepositoryProvider).hasTransactions(customer);

  Future<void> delete(CustomerModel customer, {required bool archive}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => archive
          ? ref.read(customerRepositoryProvider).archive(customer.id)
          : ref.read(customerRepositoryProvider).delete(customer.id),
    );
  }
}
