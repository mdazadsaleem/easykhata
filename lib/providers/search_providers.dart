import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/search_history_service.dart';
import '../models/search_model.dart';
import '../repositories/search_repository.dart';
import 'business_providers.dart';
import 'app_providers.dart';

final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(),
);

final searchHistoryServiceProvider = FutureProvider<SearchHistoryService>((
  ref,
) async {
  return SearchHistoryService(await SharedPreferences.getInstance());
});

class GlobalSearchState {
  const GlobalSearchState({
    this.query = '',
    this.type = SearchTypeFilter.all,
    this.dateFilter = SearchDateFilter.all,
    this.customStart,
    this.customEnd,
    this.results = const SearchResults(),
    this.history = const [],
    this.isSearching = false,
    this.error,
  });

  final String query;
  final SearchTypeFilter type;
  final SearchDateFilter dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final SearchResults results;
  final List<String> history;
  final bool isSearching;
  final String? error;

  GlobalSearchState copyWith({
    String? query,
    SearchTypeFilter? type,
    SearchDateFilter? dateFilter,
    DateTime? customStart,
    DateTime? customEnd,
    SearchResults? results,
    List<String>? history,
    bool? isSearching,
    String? error,
    bool clearError = false,
  }) => GlobalSearchState(
    query: query ?? this.query,
    type: type ?? this.type,
    dateFilter: dateFilter ?? this.dateFilter,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    results: results ?? this.results,
    history: history ?? this.history,
    isSearching: isSearching ?? this.isSearching,
    error: clearError ? null : error ?? this.error,
  );
}

final globalSearchProvider =
    AsyncNotifierProvider<GlobalSearchNotifier, GlobalSearchState>(
      GlobalSearchNotifier.new,
    );

class GlobalSearchNotifier extends AsyncNotifier<GlobalSearchState> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  Future<GlobalSearchState> build() async {
    ref.onDispose(() => _debounce?.cancel());
    final history = await ref.watch(searchHistoryServiceProvider.future);
    return GlobalSearchState(history: history.load());
  }

  void setQuery(String value, {bool immediate = false}) {
    final current = state.value ?? const GlobalSearchState();
    state = AsyncData(
      current.copyWith(
        query: value,
        results: value.trim().isEmpty ? const SearchResults() : current.results,
        isSearching: value.trim().isNotEmpty,
        clearError: true,
      ),
    );
    _debounce?.cancel();
    if (value.trim().isEmpty) return;
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 400),
      _search,
    );
  }

  void setType(SearchTypeFilter value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(type: value));
    if (current.query.trim().isNotEmpty) _search();
  }

  void setDate(
    SearchDateFilter value, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        dateFilter: value,
        customStart: customStart,
        customEnd: customEnd,
      ),
    );
    if (current.query.trim().isNotEmpty) _search();
  }

  Future<void> useHistory(String term) async {
    setQuery(term, immediate: true);
  }

  Future<void> clearHistory() async {
    final service = await ref.read(searchHistoryServiceProvider.future);
    await service.clear();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(history: const []));
    }
  }

  Future<void> _search() async {
    final current = state.value;
    if (current == null || current.query.trim().isEmpty) return;
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    if (user == null || business == null) {
      state = AsyncData(
        current.copyWith(
          isSearching: false,
          error: 'Sign in and select a business to search.',
        ),
      );
      return;
    }
    final requestId = ++_requestId;
    state = AsyncData(current.copyWith(isSearching: true, clearError: true));
    try {
      final range = _dateRange(current);
      final results = await ref
          .read(searchRepositoryProvider)
          .search(
            SearchRequest(
              ownerId: user.uid,
              businessId: business.id,
              term: current.query,
              type: current.type,
              startDate: range.$1,
              endDate: range.$2,
            ),
          );
      if (requestId != _requestId) return;
      final historyService = await ref.read(
        searchHistoryServiceProvider.future,
      );
      final history = await historyService.add(current.query);
      state = AsyncData(
        (state.value ?? current).copyWith(
          results: results,
          history: history,
          isSearching: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = AsyncData(
        (state.value ?? current).copyWith(
          isSearching: false,
          error: _message(error),
        ),
      );
    }
  }

  (DateTime?, DateTime?) _dateRange(GlobalSearchState value) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return switch (value.dateFilter) {
      SearchDateFilter.all => (null, null),
      SearchDateFilter.today => (DateTime(now.year, now.month, now.day), end),
      SearchDateFilter.last7Days => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
        end,
      ),
      SearchDateFilter.last30Days => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29)),
        end,
      ),
      SearchDateFilter.custom => (
        value.customStart,
        value.customEnd == null
            ? null
            : DateTime(
                value.customEnd!.year,
                value.customEnd!.month,
                value.customEnd!.day,
                23,
                59,
                59,
                999,
              ),
      ),
    };
  }

  String _message(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('index')) {
      return 'Search index is still being prepared. Please try again shortly.';
    }
    if (text.contains('permission')) return 'Search access was denied.';
    if (text.contains('network') || text.contains('unavailable')) {
      return 'Could not load search results. Please try again.';
    }
    return 'Search failed. Please try again.';
  }
}
