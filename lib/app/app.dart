import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_providers.dart';
import '../providers/settings_providers.dart';
import '../core/security/app_lifecycle_lock.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class SmartKhataApp extends ConsumerWidget {
  const SmartKhataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider).value ?? 'en';
    return MaterialApp.router(
      title: 'Smart Khata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        child: AppLifecycleLock(child: child!),
      ),
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
