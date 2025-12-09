import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Semantic Color System
  static const Color primary = Color(0xFF9400D3);        // hsl(283, 100%, 55%)
  static const Color accent = Color(0xFF483D8B);         // hsl(248, 39%, 49%)
  
  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF0F0F0); // Background
  static const Color lightForeground = Color(0xFF0A0A0A); // Foreground
  static const Color lightCard = Color(0xFFFFFFFF);       // Card/Secondary
  static const Color lightMutedForeground = Color(0xFF737373); // Muted Foreground
  static const Color lightDestructive = Color(0xFFDC2626);     // Destructive
  static const Color lightBorder = Color(0xFFE5E5E5);         // Border/Input

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0A0A0B);  // hsl(240, 10%, 3.9%)
  static const Color darkForeground = Color(0xFFFAFAFA);  // hsl(0, 0%, 98%)
  static const Color darkCard = Color(0xFF282A36);       // hsl(240, 3.7%, 15.9%)
  static const Color darkMutedForeground = Color(0xFFA6A6A6); // hsl(240, 5%, 64.9%)
  static const Color darkDestructive = Color(0xFF7F1D1D);     // hsl(0, 62.8%, 30.6%)
  static const Color darkBorder = Color(0xFF282A36);     // hsl(240, 3.7%, 15.9%)

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    cardColor: lightCard,
    primaryColor: primary,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: lightCard,
      error: lightDestructive,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightForeground,
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: lightForeground,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: lightForeground,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: lightForeground,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: lightForeground,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: lightForeground,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: lightMutedForeground,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: lightBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: lightBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkCard,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: darkCard,
      error: darkDestructive,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkForeground,
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: darkForeground,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkForeground,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkForeground,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: darkForeground,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: darkForeground,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: darkMutedForeground,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: darkBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: darkBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
