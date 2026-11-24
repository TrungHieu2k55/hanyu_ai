import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF123E46);
  static const jade = Color(0xFF006F79);
  static const rice = Color(0xFFF8FAFC);
  static const vermilion = Color(0xFFB42318);
  static ThemeData get light => _build();
  static ThemeData get learner => _build(learner: true);

  static ThemeData _build({bool learner = false}) => ThemeData(
    useMaterial3: true,
    fontFamily: learner ? 'Inter' : null,
    fontFamilyFallback: [
      if (learner) 'Noto Sans SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: jade,
      primary: jade,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: rice,
    appBarTheme: const AppBarTheme(
      backgroundColor: rice,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Color(0xFFDFE8E9)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 76,
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE6F4F1),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: ink),
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
    ),
  );
}
