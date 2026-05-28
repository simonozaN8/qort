import 'package:flutter/material.dart';

class AppTheme {
  // --- MĖLYNAS RĖŽIMAS (TRAINING) ---
  static final ThemeData trainingTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blueAccent,
    scaffoldBackgroundColor: const Color(0xFFF4F6F8), // Šviesus fonas
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
    ),
    colorScheme: const ColorScheme.light(
      primary: Colors.blueAccent,
      secondary: Colors.teal,
    ),
    useMaterial3: true,
  );

  // --- RAUDONAS RĖŽIMAS (COMPETITION) ---
  static final ThemeData competitionTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.redAccent,
    scaffoldBackgroundColor: const Color(0xFF121212), // Tamsus fonas
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.white54,
    ),
    colorScheme: const ColorScheme.dark(
      primary: Colors.redAccent,
      secondary: Colors.orange,
      surface: Color(0xFF1E1E1E),
    ),
    useMaterial3: true,
  );
}