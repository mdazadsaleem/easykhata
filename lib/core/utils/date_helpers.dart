/// Utility functions for robust date parsing.
DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

DateTime parseDateOrNow(dynamic value) {
  return parseDate(value) ?? DateTime.now();
}
