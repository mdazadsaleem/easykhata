import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_lock_providers.dart';

const _blue = Color(0xFF123EAD);
const _red = Color(0xFFD71920);

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String _pin = '';
  Timer? _countdown;
  bool _biometricRequested = false;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlock =
        ref.watch(appUnlockProvider).value ??
        const AppUnlockState(locked: true);
    final settings =
        ref.watch(appLockSettingsProvider).value ?? const AppLockSettings();
    if (unlock.isLockedOut && _countdown == null) {
      final until = unlock.lockoutUntil!;
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        if (!until.isAfter(DateTime.now())) {
          _countdown?.cancel();
          _countdown = null;
        }
      });
    }
    if (!_biometricRequested && settings.biometricEnabled) {
      _biometricRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(appUnlockProvider.notifier).unlockWithBiometrics();
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 24),
          child: Column(
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 38,
                backgroundColor: Color(0xFFE8EEFF),
                child: Icon(Icons.lock_rounded, color: _blue, size: 34),
              ),
              const SizedBox(height: 18),
              const Text(
                'Smart Khata is Locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                unlock.error ??
                    (unlock.isLockedOut
                        ? _remaining(unlock.lockoutUntil!)
                        : 'Enter your four-digit PIN'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unlock.error == null ? Colors.grey : _red,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: index < _pin.length
                          ? _blue
                          : const Color(0xFFD9E3FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 270,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  children: [
                    for (var number = 1; number <= 9; number++)
                      _UnlockKey(
                        label: '$number',
                        onTap: unlock.isLockedOut
                            ? null
                            : () => _digit('$number'),
                      ),
                    _UnlockKey(
                      icon: settings.biometricEnabled
                          ? Icons.fingerprint_rounded
                          : null,
                      onTap: settings.biometricEnabled && !unlock.authenticating
                          ? () => ref
                                .read(appUnlockProvider.notifier)
                                .unlockWithBiometrics()
                          : null,
                    ),
                    _UnlockKey(
                      label: '0',
                      onTap: unlock.isLockedOut ? null : () => _digit('0'),
                    ),
                    _UnlockKey(
                      icon: Icons.backspace_outlined,
                      onTap: _pin.isEmpty
                          ? null
                          : () => setState(
                              () => _pin = _pin.substring(0, _pin.length - 1),
                            ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (settings.biometricEnabled)
                const Text(
                  'Biometric unavailable? Use your PIN instead.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _digit(String value) async {
    if (_pin.length >= 4) return;
    setState(() => _pin += value);
    if (_pin.length != 4) return;
    final entered = _pin;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await ref.read(appUnlockProvider.notifier).unlockWithPin(entered);
    if (mounted) setState(() => _pin = '');
  }

  String _remaining(DateTime until) {
    final seconds = until.difference(DateTime.now()).inSeconds + 1;
    return 'Try again in ${seconds.clamp(1, 30)} seconds.';
  }
}

class _UnlockKey extends StatelessWidget {
  const _UnlockKey({this.label, this.icon, this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Center(
      child: icon != null
          ? Icon(icon, color: onTap == null ? Colors.grey : _blue, size: 27)
          : label == null
          ? const SizedBox()
          : Text(
              label!,
              style: TextStyle(
                color: onTap == null ? Colors.grey : null,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );
}
