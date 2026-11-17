import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/routes/app_routes.dart';
import '../../models/search_model.dart';
import '../../providers/search_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _red = Color(0xFFD71920);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _page = Color(0xFFF8F9FD);

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(globalSearchProvider);
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Search',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(
          message: 'Could not prepare search.',
          onRetry: () => ref.invalidate(globalSearchProvider),
        ),
        data: (state) => Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: ref.read(globalSearchProvider.notifier).setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search customers, transactions, cashbook...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                ref
                                    .read(globalSearchProvider.notifier)
                                    .setQuery('');
                                _focusNode.requestFocus();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeFilter(
                          value: state.type,
                          onChanged: (value) => ref
                              .read(globalSearchProvider.notifier)
                              .setType(value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateFilter(
                          value: state.dateFilter,
                          onChanged: (value) => _setDateFilter(value, state),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (state.isSearching) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(state)),
          ],
        ),
      ),
    );
  }

  Widget _body(GlobalSearchState state) {
    if (state.query.trim().isEmpty) {
      return _RecentSearches(
        history: state.history,
        onSelect: (term) {
          _controller.text = term;
          _controller.selection = TextSelection.collapsed(offset: term.length);
          ref.read(globalSearchProvider.notifier).useHistory(term);
        },
        onClear: () => ref.read(globalSearchProvider.notifier).clearHistory(),
      );
    }
    if (state.error != null) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref
            .read(globalSearchProvider.notifier)
            .setQuery(state.query, immediate: true),
      );
    }
    if (state.isSearching && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.results.isEmpty) return const _NoResults();
    return _ResultsList(results: state.results);
  }

  Future<void> _setDateFilter(
    SearchDateFilter filter,
    GlobalSearchState state,
  ) async {
    if (filter != SearchDateFilter.custom) {
      ref.read(globalSearchProvider.notifier).setDate(filter);
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: state.customStart != null && state.customEnd != null
          ? DateTimeRange(start: state.customStart!, end: state.customEnd!)
          : null,
    );
    if (range != null) {
      ref
          .read(globalSearchProvider.notifier)
          .setDate(
            SearchDateFilter.custom,
            customStart: range.start,
            customEnd: range.end,
          );
    }
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.value, required this.onChanged});
  final SearchTypeFilter value;
  final ValueChanged<SearchTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField(
    initialValue: value,
    isDense: true,
    decoration: const InputDecoration(
      labelText: 'Result type',
      prefixIcon: Icon(Icons.tune_rounded, size: 18),
    ),
    items: SearchTypeFilter.values
        .map(
          (filter) =>
              DropdownMenuItem(value: filter, child: Text(_typeLabel(filter))),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({required this.value, required this.onChanged});
  final SearchDateFilter value;
  final ValueChanged<SearchDateFilter> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField(
    initialValue: value,
    isDense: true,
    decoration: const InputDecoration(
      labelText: 'Date',
      prefixIcon: Icon(Icons.calendar_today_outlined, size: 17),
    ),
    items: SearchDateFilter.values
        .map(
          (filter) =>
              DropdownMenuItem(value: filter, child: Text(_dateLabel(filter))),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.history,
    required this.onSelect,
    required this.onClear,
  });
  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded, color: _blue, size: 52),
            SizedBox(height: 12),
            Text(
              'Search your business',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 5),
            Text(
              'Find accounts, transactions and cashbook entries.',
              style: TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RECENT SEARCHES',
                style: TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear history')),
          ],
        ),
        ...history.map(
          (term) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, color: _muted),
            title: Text(term, style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.north_west_rounded, size: 16),
            onTap: () => onSelect(term),
          ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});
  final SearchResults results;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    children: [
      if (results.customers.isNotEmpty)
        _ResultSection(title: 'CUSTOMERS', items: results.customers),
      if (results.suppliers.isNotEmpty)
        _ResultSection(title: 'SUPPLIERS', items: results.suppliers),
      if (results.transactions.isNotEmpty)
        _ResultSection(title: 'TRANSACTIONS', items: results.transactions),
      if (results.cashbookEntries.isNotEmpty)
        _ResultSection(title: 'CASHBOOK', items: results.cashbookEntries),
    ],
  );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.items});
  final String title;
  final List<SearchResult> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7, top: 4),
        child: Text(
          title,
          style: const TextStyle(
            color: _muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: items
              .map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _resultColor(
                      item.type,
                    ).withValues(alpha: .1),
                    child: Icon(
                      _resultIcon(item.type),
                      color: _resultColor(item.type),
                      size: 19,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (item.subtitle.isNotEmpty) item.subtitle,
                      if (item.date != null)
                        DateFormat('dd MMM yyyy').format(item.date!),
                    ].join(' • '),
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                  trailing: item.amount == null
                      ? const Icon(Icons.chevron_right_rounded, size: 18)
                      : Text(
                          NumberFormat.currency(
                            symbol: '₨ ',
                            decimalDigits: 0,
                          ).format(item.amount),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  onTap: () => _open(context, item),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  void _open(BuildContext context, SearchResult item) {
    switch (item.type) {
      case SearchResultType.customer:
      case SearchResultType.supplier:
        context.push('${AppRoutes.customerDetails}/${item.id}');
      case SearchResultType.transaction:
        context.push('${AppRoutes.editTransaction}/${item.id}');
      case SearchResultType.cashbook:
        context.push('${AppRoutes.editCashEntry}/${item.id}');
    }
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, color: _muted, size: 48),
        SizedBox(height: 10),
        Text(
          'No results found',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'Try another term or change the filters.',
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, color: _red, size: 46),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

String _typeLabel(SearchTypeFilter filter) => switch (filter) {
  SearchTypeFilter.all => 'All',
  SearchTypeFilter.customers => 'Customers',
  SearchTypeFilter.suppliers => 'Suppliers',
  SearchTypeFilter.transactions => 'Transactions',
  SearchTypeFilter.cashbook => 'Cashbook',
};

String _dateLabel(SearchDateFilter filter) => switch (filter) {
  SearchDateFilter.all => 'Any date',
  SearchDateFilter.today => 'Today',
  SearchDateFilter.last7Days => 'Last 7 days',
  SearchDateFilter.last30Days => 'Last 30 days',
  SearchDateFilter.custom => 'Custom',
};

IconData _resultIcon(SearchResultType type) => switch (type) {
  SearchResultType.customer => Icons.person_outline_rounded,
  SearchResultType.supplier => Icons.local_shipping_outlined,
  SearchResultType.transaction => Icons.receipt_long_outlined,
  SearchResultType.cashbook => Icons.account_balance_wallet_outlined,
};

Color _resultColor(SearchResultType type) => switch (type) {
  SearchResultType.customer => _blue,
  SearchResultType.supplier => const Color(0xFF6941C6),
  SearchResultType.transaction => _green,
  SearchResultType.cashbook => const Color(0xFFF79009),
};
