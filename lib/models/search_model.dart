enum SearchResultType { customer, supplier, transaction, cashbook }

enum SearchTypeFilter { all, customers, suppliers, transactions, cashbook }

enum SearchDateFilter { all, today, last7Days, last30Days, custom }

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    this.referenceId,
    this.amount,
  });

  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final DateTime? date;
  final String? referenceId;
  final double? amount;
}

class SearchResults {
  const SearchResults({
    this.customers = const [],
    this.suppliers = const [],
    this.transactions = const [],
    this.cashbookEntries = const [],
  });

  final List<SearchResult> customers;
  final List<SearchResult> suppliers;
  final List<SearchResult> transactions;
  final List<SearchResult> cashbookEntries;

  bool get isEmpty =>
      customers.isEmpty &&
      suppliers.isEmpty &&
      transactions.isEmpty &&
      cashbookEntries.isEmpty;
}

class SearchRequest {
  const SearchRequest({
    required this.ownerId,
    required this.businessId,
    required this.term,
    this.type = SearchTypeFilter.all,
    this.startDate,
    this.endDate,
  });

  final String ownerId;
  final String businessId;
  final String term;
  final SearchTypeFilter type;
  final DateTime? startDate;
  final DateTime? endDate;
}
