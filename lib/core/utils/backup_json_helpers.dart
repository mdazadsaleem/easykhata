dynamic backupJsonValue(dynamic value) {
  if (value is DateTime) {
    return {r'$type': 'timestamp', 'iso': value.toUtc().toIso8601String()};
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), backupJsonValue(item)),
    );
  }
  if (value is Iterable) return value.map(backupJsonValue).toList();
  return value;
}

dynamic restoreJsonValue(dynamic value) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    if (map[r'$type'] == 'timestamp') {
      final date = DateTime.tryParse(map['iso'] as String? ?? '');
      if (date == null) throw const FormatException('Invalid backup date.');
      return date;
    }
    return map.map(
      (key, item) => MapEntry(key, restoreJsonValue(item)),
    );
  }
  if (value is List) {
    return value.map((item) => restoreJsonValue(item)).toList();
  }
  return value;
}

Map<String, dynamic> jsonSafeMap(Map<String, dynamic> source) =>
    source.map((key, value) => MapEntry(key, backupJsonValue(value)));
