import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_lock_providers.dart';
import '../../screens/app_lock/unlock_screen.dart';

class AppLifecycleLock extends ConsumerStatefulWidget {
  const AppLifecycleLock({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLifecycleLock> createState() => _AppLifecycleLockState();
}

class _AppLifecycleLockState extends ConsumerState<AppLifecycleLock>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed || _backgroundedAt == null) return;
    final settings = ref.read(appLockSettingsProvider).value;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (settings?.hasPin != true || settings?.lockWhenMinimized != true) return;
    if (elapsed >= _duration(settings!.timeout)) {
      ref.read(appUnlockProvider.notifier).lock();
    }
  }

  Duration _duration(String timeout) => switch (timeout) {
    'Immediately' => Duration.zero,
    '1 minute' => const Duration(minutes: 1),
    '15 minutes' => const Duration(minutes: 15),
    _ => const Duration(minutes: 5),
  };

  @override
  Widget build(BuildContext context) {
    final unlock = ref.watch(appUnlockProvider);
    return unlock.when(
      loading: () => const ColoredBox(
        color: Color(0xFFF8F9FD),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => widget.child,
      data: (state) => state.locked ? const UnlockScreen() : widget.child,
    );
  }
}
