import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/otp_route_args.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/startup_providers.dart';

const _blue = Color(0xFF0739B6);
const _background = Color(0xFFF8F9FF);

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _navigationStarted = false;

  Future<void> _submitPhone() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        ref.read(phoneAuthProvider).isLoading) {
      return;
    }
    FocusScope.of(context).unfocus();
    _navigationStarted = false;
    await ref.read(phoneAuthProvider.notifier).sendOtp(_phoneController.text);
  }

  Future<void> _continueWithGoogle() async {
    if (ref.read(phoneAuthProvider).isLoading) return;
    _navigationStarted = false;
    await ref.read(phoneAuthProvider.notifier).signInWithGoogle();
  }

  Future<void> _openAuthenticatedDestination() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _navigationStarted = false;
      _showMessage('Authentication did not return a valid user.');
      return;
    }
    try {
      final business = await ref
          .read(businessRepositoryProvider)
          .watchForOwner(user.uid)
          .first
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      ref.invalidate(startupProvider);
      context.go(business == null ? AppRoutes.businessSetup : AppRoutes.main);
    } catch (_) {
      if (!mounted) return;
      _navigationStarted = false;
      _showMessage('Could not load your account. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLegalDialog(String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          title == 'Terms of Service'
              ? 'By using Smart Khata, you agree to provide accurate account '
                    'information and use the service lawfully.'
              : 'Smart Khata stores your account and business information '
                    'securely to provide ledger and bookkeeping features.',
        ),
        actions: [
          TextButton(onPressed: context.pop, child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(phoneAuthProvider);
    ref.listen<PhoneAuthState>(phoneAuthProvider, (previous, next) {
      if (next.status == PhoneAuthStatus.error &&
          next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showMessage(next.errorMessage!);
      }
      if (_navigationStarted) return;
      if (next.status == PhoneAuthStatus.codeSent &&
          next.verificationId != null &&
          next.phoneNumber != null) {
        _navigationStarted = true;
        context.push(
          AppRoutes.otp,
          extra: OtpRouteArgs(
            phoneNumber: next.phoneNumber!,
            verificationId: next.verificationId!,
            resendToken: next.resendToken,
          ),
        );
      } else if (next.status == PhoneAuthStatus.autoVerified) {
        _navigationStarted = true;
        _openAuthenticatedDestination();
      }
    });
    final loading = auth.isLoading;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x300739B6),
                              blurRadius: 16,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 31,
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Smart Khata',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your mobile number to continue',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFD7DCE8)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MOBILE NUMBER',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitPhone(),
                              validator: Validators.pakistanPhone,
                              maxLength: 13,
                              style: const TextStyle(
                                color: Color(0xFF24324A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '300 1234567',
                                hintStyle: const TextStyle(
                                  color: Color(0xFFB6BECE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 112,
                                  minHeight: 52,
                                ),
                                prefixIcon: const SizedBox(
                                  width: 112,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            '+92 (PK)',
                                            style: TextStyle(
                                              color: Color(0xFF475467),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 52,
                                        child: VerticalDivider(
                                          width: 1,
                                          thickness: 1,
                                          color: Color(0xFFD2D8E4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF1F4FC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 17,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD2D8E4),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD2D8E4),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(7),
                                  borderSide: const BorderSide(
                                    color: _blue,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: loading ? null : _submitPhone,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  elevation: 4,
                                  shadowColor: const Color(0x500739B6),
                                ),
                                child: loading
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(width: 9),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Color(0xFF98A2B3),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: _SocialButton(
                                label: 'Continue with Google',
                                loading: loading,
                                icon: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onPressed: _continueWithGoogle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'By continuing, you agree to Smart Khata’s',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _showLegalDialog('Terms of Service'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 26),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Terms of Service',
                              style: TextStyle(fontSize: 9),
                            ),
                          ),
                          const Text(
                            'and',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 9,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showLegalDialog('Privacy Policy'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 26),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                      const Offstage(
                        offstage: true,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Text.rich(
                            TextSpan(
                              text:
                                  'By continuing, you agree to Smart Khata’s\n',
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 9,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF344054),
        side: const BorderSide(color: Color(0xFFD7DCE8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    ),
  );
}
