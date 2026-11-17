import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/otp_route_args.dart';
import '../../providers/otp_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({required this.arguments, super.key});

  final OtpRouteArgs arguments;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    ref.read(otpProvider.notifier).initialize(widget.arguments);
    _startTimer();
  }

  String get _otp => _controllers.map((controller) => controller.text).join();

  String get _maskedPhone {
    final digits = widget.arguments.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return widget.arguments.phoneNumber;
    return '+92 3** *** ${digits.substring(digits.length - 3)}';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      final code = digits.substring(0, digits.length.clamp(0, 6));
      for (var position = 0; position < 6; position++) {
        _controllers[position].text = position < code.length
            ? code[position]
            : '';
      }
      if (code.length == 6) {
        FocusScope.of(context).unfocus();
      } else {
        _focusNodes[code.length].requestFocus();
      }
      return;
    }
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) FocusScope.of(context).unfocus();
  }

  Future<void> _verify() async {
    await ref.read(otpProvider.notifier).verify(_otp);
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0 || ref.read(otpProvider).isBusy) return;
    await ref.read(otpProvider.notifier).resend();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);
    ref.listen<OtpState>(otpProvider, (previous, next) {
      if (next.status == OtpStatus.error &&
          next.message != null &&
          next.message != previous?.message) {
        _showMessage(next.message!);
      }
      if (next.status == OtpStatus.codeResent &&
          previous?.status != OtpStatus.codeResent) {
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes.first.requestFocus();
        _startTimer();
        _showMessage(next.message ?? 'A new verification code was sent.');
      }
      if (!_navigationStarted &&
          next.status == OtpStatus.success &&
          next.destination != null) {
        _navigationStarted = true;
        context.go(next.destination!);
      }
    });
    final verifying = otpState.status == OtpStatus.verifying;
    final resending = otpState.status == OtpStatus.resending;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2448B9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verify Your Number',
                      style: TextStyle(
                        color: Color(0xFF07152B),
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: "We've sent a 6-digit verification code to\n",
                        children: [
                          TextSpan(
                            text: _maskedPhone,
                            style: const TextStyle(
                              color: Color(0xFF07152B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4E596D),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 31),
                    AutofillGroup(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: 38,
                            height: 44,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              enabled: !otpState.isBusy,
                              autofocus: index == 0,
                              keyboardType: TextInputType.number,
                              textInputAction: index == 5
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF07152B),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              autofillHints: index == 0
                                  ? const [AutofillHints.oneTimeCode]
                                  : null,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  index == 0 ? 6 : 1,
                                ),
                              ],
                              onChanged: (value) =>
                                  _onDigitChanged(index, value),
                              onSubmitted: (_) {
                                if (index == 5) _verify();
                              },
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFFAFBFF),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(5),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD1D7E3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(5),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD1D7E3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(5),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFF1749CD),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFF173A94),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF173A94),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _secondsRemaining == 0 && !resending
                          ? _resend
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0733A2),
                        disabledForegroundColor: const Color(0xFF6B7790),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        resending ? 'Sending...' : 'Resend Code',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0733A2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 3,
                          shadowColor: const Color(0x400733A2),
                        ),
                        onPressed: otpState.isBusy ? null : _verify,
                        child: verifying
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: otpState.isBusy ? null : context.pop,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text(
                        'Change Number',
                        style: TextStyle(fontSize: 10.5),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0733A2),
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'Secure accounting by Smart Khata. By continuing, you agree\n'
                        'to our Terms of Service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8A93A4),
                          fontSize: 8.5,
                          height: 1.4,
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
    );
  }
}
