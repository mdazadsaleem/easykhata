import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/startup_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  void _navigate(StartupDestination destination) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(destination.route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupProvider);
    ref.listen<AsyncValue<StartupDestination>>(startupProvider, (
      previous,
      next,
    ) {
      next.whenData(_navigate);
    });
    if (startup case AsyncData(:final value)) {
      _navigate(value);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF062D91),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF07349D),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123BAA), Color(0xFF07349D), Color(0xFF032B8E)],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment(0, -0.02),
                  child: _SplashBrand(),
                ),
                Align(
                  alignment: const Alignment(0, 0.83),
                  child: _SplashProgress(
                    error: startup.hasError
                        ? _friendlyError(startup.error)
                        : null,
                    onRetry: startup.hasError
                        ? () {
                            _hasNavigated = false;
                            ref.read(startupProvider.notifier).retry();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object? error) {
    final text = error.toString().toLowerCase();
    if (text.contains('network') ||
        text.contains('unavailable') ||
        text.contains('timeout')) {
      return 'Unable to connect. Check your internet and try again.';
    }
    return 'Smart Khata could not start securely. Please try again.';
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Transform.rotate(
        angle: -math.pi / 45,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28001551),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Color(0xFF06349F),
            size: 34,
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Smart Khata',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.45,
        ),
      ),
      const SizedBox(height: 9),
      const Text(
        'Simple Business, Clear Accounts',
        style: TextStyle(
          color: Color(0xFFE8EEFF),
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    ],
  );
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (error == null)
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Color(0xFFB8C8F3),
            backgroundColor: Color(0x4DFFFFFF),
          ),
        ),
      if (error == null) ...[
        const SizedBox(height: 14),
        const Text(
          'S E C U R I N G   L E D G E R',
          style: TextStyle(
            color: Color(0xFF9DB3E8),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFDCE5FF), fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFB8C8F3)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Retry'),
        ),
      ],
    ],
  );
}
