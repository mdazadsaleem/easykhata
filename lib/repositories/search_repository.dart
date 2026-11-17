import '../core/database/hive_database.dart';
import '../models/search_model.dart';
import '../core/utils/date_helpers.dart';

class SearchRepository {
  SearchRepository();

  Future<SearchResults> search(SearchRequest request) async {
    final term = normalizeSearchText(request.term);
    if (term.isEmpty) return const SearchResults();

    final includePeople =
        request.type == SearchTypeFilter.all ||
        request.type == SearchTypeFilter.customers ||
        request.type == SearchTypeFilter.suppliers;
    final includeTransactions =
        request.type == SearchTypeFilter.all ||
        request.type == SearchTypeFilter.transactions;
    final includeCashbook =
        request.type == SearchTypeFilter.all ||
        request.type == SearchTypeFilter.cashbook;

    final people = includePeople ? _searchCustomers(request, term) : <SearchResult>[];
    final transactions =
        includeTransactions ? _searchTransactions(request, term) : <SearchResult>[];
    final cashbook =
        includeCashbook ? _searchCashbook(request, term) : <SearchResult>[];

    return SearchResults(
      customers: request.type == SearchTypeFilter.suppliers
          ? const []
          : people
                .where((item) => item.type == SearchResultType.customer)
                .toList(),
      suppliers: request.type == SearchTypeFilter.customers
          ? const []
          : people
                .where((item) => item.type == SearchResultType.supplier)
                .toList(),
      transactions: transactions,
      cashbookEntries: cashbook,
    );
  }

  List<SearchResult> _searchCustomers(SearchRequest request, String term) {
    final box = HiveDatabase.instance.customersBox;
    final digits = term.replaceAll(RegExp(r'\D'), '');

    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((data) {
          if (data['ownerId'] != request.ownerId ||
              data['businessId'] != request.businessId ||
              data['isActive'] == false) {
            return false;
          }
          if (!_withinDate(data['createdAt'], request)) return false;

          final name = (data['nameNormalized'] ?? data['name'] ?? '').toString().toLowerCase();
          final phone = (data['phoneNormalized'] ?? data['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

          return name.contains(term) || (digits.isNotEmpty && phone.contains(digits));
        })
        .take(25)
        .map((data) {
          final supplier = data['accountType'] == 'supplier';
          return SearchResult(
            id: data['id'] as String? ?? '',
            type: supplier ? SearchResultType.supplier : SearchResultType.customer,
            title: data['name'] as String? ?? 'Unknown account',
            subtitle: data['phone'] as String? ?? '',
            date: parseDate(data['createdAt']),
            amount: (data['currentBalance'] as num?)?.toDouble(),
          );
        })
        .toList();
  }

  List<SearchResult> _searchTransactions(SearchRequest request, String term) {
    final box = HiveDatabase.instance.transactionsBox;

    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((data) {
          if (data['ownerId'] != request.ownerId ||
              data['businessId'] != request.businessId) {
            return false;
          }
          if (!_withinDate(data['transactionDate'], request)) return false;

          final desc = (data['descriptionNormalized'] ?? data['description'] ?? '').toString().toLowerCase();
          final custName = (data['customerNameNormalized'] ?? data['customerName'] ?? '').toString().toLowerCase();

          return desc.contains(term) || custName.contains(term);
        })
        .take(25)
        .map((data) {
          final type = data['transactionType'] as String? ?? data['type'] as String? ?? 'gave';
          return SearchResult(
            id: data['id'] as String? ?? '',
            type: SearchResultType.transaction,
            title: data['customerName'] as String? ?? 'Transaction',
            subtitle: '${type == 'gave' ? 'You gave' : 'You received'}${_description(data['description'])}',
            date: parseDate(data['transactionDate']),
            amount: (data['amount'] as num?)?.toDouble(),
            referenceId: data['customerId'] as String?,
          );
        })
        .toList();
  }

  List<SearchResult> _searchCashbook(SearchRequest request, String term) {
    final box = HiveDatabase.instance.cashbookBox;

    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((data) {
          if (data['ownerId'] != request.ownerId ||
              data['businessId'] != request.businessId) {
            return false;
          }
          if (!_withinDate(data['entryDate'], request)) return false;

          final desc = (data['descriptionNormalized'] ?? data['description'] ?? '').toString().toLowerCase();
          final cat = (data['categoryNormalized'] ?? data['category'] ?? '').toString().toLowerCase();

          return desc.contains(term) || cat.contains(term);
        })
        .take(25)
        .map((data) {
          return SearchResult(
            id: data['id'] as String? ?? '',
            type: SearchResultType.cashbook,
            title: data['category'] as String? ?? 'Cashbook entry',
            subtitle: data['description'] as String? ?? '',
            date: parseDate(data['entryDate']),
            amount: (data['amount'] as num?)?.toDouble(),
          );
        })
        .toList();
  }

  bool _withinDate(dynamic value, SearchRequest request) {
    if (request.startDate == null && request.endDate == null) return true;
    final date = parseDate(value);
    if (date == null) return false;
    if (request.startDate != null && date.isBefore(request.startDate!)) {
      return false;
    }
    if (request.endDate != null && date.isAfter(request.endDate!)) return false;
    return true;
  }

  String _description(dynamic value) {
    final description = (value as String? ?? '').trim();
    return description.isEmpty ? '' : ' • $description';
  }
}

String normalizeSearchText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
