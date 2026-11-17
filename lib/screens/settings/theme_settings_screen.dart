import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: RadioGroup<ThemeMode>(
        groupValue: selected,
        onChanged: (value) {
          if (value != null) {
            ref.read(themeModeProvider.notifier).set(value);
          }
        },
        child: Column(
          children: ThemeMode.values
              .map(
                (mode) => RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(switch (mode) {
                    ThemeMode.system => 'System Default',
                    ThemeMode.light => 'Light Mode',
                    ThemeMode.dark => 'Dark Mode',
                  }),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
