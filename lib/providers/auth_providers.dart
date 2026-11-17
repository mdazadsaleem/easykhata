import 'package:flutter_riverpod/flutter_riverpod.dart';


enum PhoneAuthStatus { idle, sending, codeSent, autoVerified, error }

class PhoneAuthState {
  const PhoneAuthState({
    this.status = PhoneAuthStatus.idle,
    this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.errorMessage,
  });

  final PhoneAuthStatus status;
  final String? phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;

  bool get isLoading => status == PhoneAuthStatus.sending;
}

final phoneAuthProvider = NotifierProvider<PhoneAuthNotifier, PhoneAuthState>(
  PhoneAuthNotifier.new,
);

class PhoneAuthNotifier extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  Future<void> sendOtp(String input) async {
    state = const PhoneAuthState(status: PhoneAuthStatus.autoVerified);
  }

  Future<void> signInWithGoogle() async {
    state = const PhoneAuthState(status: PhoneAuthStatus.autoVerified);
  }
}

String? normalizePakistanPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) digits = digits.substring(2);
  if (digits.startsWith('92')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return RegExp(r'^3\d{9}$').hasMatch(digits) ? '+92$digits' : null;
}
