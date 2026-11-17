import 'package:flutter/material.dart';

abstract final class AppColors {
  static const green = Color(0xFF168A4A);
  static const blue = Color(0xFF173EB5);
  static const navy = Color(0xFF10233B);
  static const red = Color(0xFFD64545);
  static const orange = Color(0xFFF59E0B);
  static const surface = Color(0xFFF7F8FC);
  static const border = Color(0xFFD8DDE9);
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final generated = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: brightness,
    );
    final scheme = generated.copyWith(
      primary: AppColors.blue,
      secondary: AppColors.green,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppColors.surface
          : scheme.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFF1F4FA)
            : scheme.surfaceContainerHighest.withValues(alpha: .45),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
          borderSide: BorderSide(color: AppColors.blue, width: 1.3),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: .7,
        space: 1,
      ),
    );
  }
}
