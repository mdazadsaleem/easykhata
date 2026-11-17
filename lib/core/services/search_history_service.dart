import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  SearchHistoryService(this._preferences);

  final SharedPreferences _preferences;
  static const _key = 'global_search_history';
  static const _maximumTerms = 10;

  List<String> load() =>
      List.unmodifiable(_preferences.getStringList(_key) ?? const []);

  Future<List<String>> add(String value) async {
    final term = value.trim();
    if (term.isEmpty) return load();
    final history = load()
        .where((saved) => saved.toLowerCase() != term.toLowerCase())
        .toList();
    history.insert(0, term);
    final limited = history.take(_maximumTerms).toList();
    await _preferences.setStringList(_key, limited);
    return limited;
  }

  Future<void> clear() => _preferences.remove(_key);
}
