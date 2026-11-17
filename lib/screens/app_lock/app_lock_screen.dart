import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_lock_providers.dart';

const _blue = Color(0xFF123EAD);
const _red = Color(0xFFD71920);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);
const _border = Color(0xFFD8DDE9);
const _page = Color(0xFFF8F9FD);

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = '';
  String? _firstPin;
  String? _message;
  bool _verifiedCurrentPin = false;

  Future<void> _enter(String digit) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
    if (_pin.length != 4) return;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final settings =
        ref.read(appLockSettingsProvider).value ?? const AppLockSettings();
    if (settings.hasPin && !_verifiedCurrentPin) {
      final verified = await ref
          .read(appLockSettingsProvider.notifier)
          .verifyPin(_pin);
      if (!mounted) return;
      if (!verified) {
        setState(() {
          _pin = '';
          _message = 'The current PIN is incorrect.';
        });
        return;
      }
      setState(() {
        _verifiedCurrentPin = true;
        _pin = '';
        _message = 'Enter your new four-digit PIN';
      });
      return;
    }
    if (_firstPin == null) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _message = 'Re-enter your PIN to confirm';
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _pin = '';
        _message = 'PINs did not match. Please try again.';
      });
      return;
    }
    await ref.read(appLockSettingsProvider.notifier).savePin(_pin);
    if (!mounted) return;
    setState(() {
      _firstPin = null;
      _verifiedCurrentPin = false;
      _pin = '';
      _message = 'Your new PIN has been saved securely.';
    });
  }

  Future<void> _removePin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove app lock?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Current PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || !mounted) return;
    try {
      await ref.read(appLockSettingsProvider.notifier).removePin(pin);
      if (mounted) {
        setState(() {
          _pin = '';
          _firstPin = null;
          _verifiedCurrentPin = false;
          _message = 'App lock has been removed.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'The current PIN is incorrect.');
      }
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appLockSettingsProvider);
    final settings = settingsAsync.value ?? const AppLockSettings();
    ref.listen(appLockSettingsProvider, (previous, next) {
      final error = next.value?.error;
      if (error != null && error != previous?.value?.error && mounted) {
        setState(() => _message = error);
      }
    });

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: const Text(
          'App Lock',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (settings.hasPin)
            TextButton(
              onPressed: _removePin,
              child: const Text(
                'Remove PIN',
                style: TextStyle(color: _red, fontSize: 9),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 15),
              child: Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 28),
        children: [
          _PinCard(
            pinLength: _pin.length,
            hasPin: settings.hasPin,
            message: _message,
            onDigit: _enter,
            onDelete: _deleteDigit,
          ),
          const SizedBox(height: 13),
          const _SectionLabel('Biometric Security'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.fingerprint_rounded,
                title: 'Enable Fingerprint / Touch ID',
                subtitle: 'Unlock app with registered biometric data',
                value: settings.fingerprint,
                onChanged: settingsAsync.isLoading
                    ? null
                    : ref.read(appLockSettingsProvider.notifier).setFingerprint,
              ),
              _ToggleRow(
                icon: Icons.face_retouching_natural_outlined,
                title: 'Enable Face ID',
                subtitle: 'Available on supported devices',
                value: settings.faceId,
                onChanged: settingsAsync.isLoading
                    ? null
                    : ref.read(appLockSettingsProvider.notifier).setFaceId,
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 13),
          const _SectionLabel('Automation & Preferences'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUTO-LOCK TIMER',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: settings.timeout,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F6FC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: _border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Immediately',
                          child: Text('Immediately'),
                        ),
                        DropdownMenuItem(
                          value: '1 minute',
                          child: Text('After 1 minute'),
                        ),
                        DropdownMenuItem(
                          value: '5 minutes',
                          child: Text('After 5 minutes'),
                        ),
                        DropdownMenuItem(
                          value: '15 minutes',
                          child: Text('After 15 minutes'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(appLockSettingsProvider.notifier)
                              .setTimeout(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              _ToggleRow(
                icon: Icons.minimize_rounded,
                title: 'Lock when minimized',
                subtitle: 'Require security when switching back to app',
                value: settings.lockWhenMinimized,
                onChanged: settingsAsync.isLoading
                    ? null
                    : ref
                          .read(appLockSettingsProvider.notifier)
                          .setLockWhenMinimized,
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _red, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Forgot your PIN? You will need to re-install the app '
                        'and all local data will be cleared for security.',
                        style: TextStyle(
                          color: _red,
                          fontSize: 8,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pinLength,
    required this.hasPin,
    required this.message,
    required this.onDigit,
    required this.onDelete,
  });
  final int pinLength;
  final bool hasPin;
  final String? message;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Text(
          hasPin ? 'Change Your PIN' : 'Create New PIN',
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message ?? 'Enter a 4 digit PIN for quick access',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: message?.contains('did not') == true ? _red : _muted,
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (index) => Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: index < pinLength ? _blue : const Color(0xFFD9E3FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          children: [
            for (var number = 1; number <= 9; number++)
              _Key(
                label: number.toString(),
                onTap: () => onDigit(number.toString()),
              ),
            const SizedBox(),
            _Key(label: '0', onTap: () => onDigit('0')),
            _Key(icon: Icons.backspace_outlined, onTap: onDelete),
          ],
        ),
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Center(
      child: icon == null
          ? Text(
              label!,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(icon, color: _ink, size: 17),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 7),
    child: Text(
      label,
      style: const TextStyle(
        color: _blue,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Column(children: children),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(11, 9, 7, 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: _blue, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 7,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: _blue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
      if (divider)
        const Divider(height: 1, indent: 52, color: Color(0xFFE8EBF2)),
    ],
  );
}
