import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/hive_database.dart';
import 'core/services/theme_persistence_service.dart';
import 'providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.instance.init();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        themePersistenceServiceProvider.overrideWithValue(
          ThemePersistenceService(preferences),
        ),
      ],
      child: const SmartKhataApp(),
    ),
  );
}
