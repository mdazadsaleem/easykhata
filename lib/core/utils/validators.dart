abstract final class Validators {
  static String? required(String? value, [String label = 'Field']) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;

  static String? pakistanPhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    return RegExp(r'^(?:\+?92|0)?3\d{9}$').hasMatch(phone)
        ? null
        : 'Enter a valid Pakistan mobile number.';
  }

  static String? amount(String? value) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive amount.' : null;
  }

  static String? otp(String? value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
      ? null
      : 'Enter the 6-digit OTP.';
}
