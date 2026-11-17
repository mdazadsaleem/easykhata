import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/routes/app_routes.dart';
import '../app/routes/otp_route_args.dart';
import '../repositories/user_repository.dart';

enum OtpStatus { idle, verifying, resending, codeResent, success, error }

class OtpState {
  const OtpState({
    this.status = OtpStatus.idle,
    this.verificationId = '',
    this.phoneNumber = '',
    this.resendToken,
    this.destination,
    this.message,
  });

  final OtpStatus status;
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
  final String? destination;
  final String? message;

  bool get isBusy =>
      status == OtpStatus.verifying || status == OtpStatus.resending;
}

final userRepositoryProvider = Provider(
  (ref) => UserRepository(),
);

final otpProvider = NotifierProvider<OtpNotifier, OtpState>(OtpNotifier.new);

class OtpNotifier extends Notifier<OtpState> {
  @override
  OtpState build() => const OtpState();

  void initialize(OtpRouteArgs arguments) {
    if (state.verificationId == arguments.verificationId) return;
    state = OtpState(
      verificationId: arguments.verificationId,
      phoneNumber: arguments.phoneNumber,
      resendToken: arguments.resendToken,
    );
  }

  Future<void> verify(String code) async {
    state = const OtpState(
      status: OtpStatus.success,
      destination: AppRoutes.main,
    );
  }

  Future<void> resend() async {
    state = const OtpState(
      status: OtpStatus.codeResent,
      message: 'A new code was sent.',
    );
  }
}
