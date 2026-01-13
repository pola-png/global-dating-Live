import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Modern Color Palette
  static const Color primary = Color(0xFF9400D3);        // Purple
  static const Color secondary = Color(0xFF483D8B);      // Dark Slate Blue
  static const Color tertiary = Color(0xFF6A5ACD);       // Slate Blue
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);        // Emerald
  static const Color warning = Color(0xFFF59E0B);        // Amber
  static const Color error = Color(0xFFEF4444);          // Red
  static const Color info = Color(0xFF3B82F6);           // Blue
  
  // Light Theme Colors
  static const Color lightSurface = Color(0xFFFFFBFE);
  static const Color lightSurfaceVariant = Color(0xFFF4EFF4);
  static const Color lightOnSurface = Color(0xFF1D1B20);
  static const Color lightOnSurfaceVariant = Color(0xFF49454F);
  static const Color lightOutline = Color(0xFF79747E);
  static const Color lightOutlineVariant = Color(0xFFCAC4D0);
  
  // Dark Theme Colors
  static const Color darkSurface = Color(0xFF141218);
  static const Color darkSurfaceVariant = Color(0xFF49454F);
  static const Color darkOnSurface = Color(0xFFE6E0E9);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);
  static const Color darkOutline = Color(0xFF938F99);
  static const Color darkOutlineVariant = Color(0xFF49454F);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: lightSurface,
      surfaceContainerHighest: lightSurfaceVariant,
      onSurface: lightOnSurface,
      onSurfaceVariant: lightOnSurfaceVariant,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      error: error,
    ),
    
    // Enhanced Typography
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    ),
    
    // Enhanced Card Theme
    cardTheme: const CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Enhanced Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: lightSurface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: lightOnSurface,
      ),
    ),
    
    // Enhanced Button Themes
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    
    // Enhanced Input Decoration
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: lightSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: error, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    
    // Enhanced App Bar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: lightSurface,
      foregroundColor: lightOnSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: lightOnSurface,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    
    // Enhanced Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 3,
      backgroundColor: lightSurface,
      selectedItemColor: primary,
      unselectedItemColor: lightOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: darkSurface,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      error: error,
    ),
    
    // Enhanced Typography
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    ),
    
    // Enhanced Card Theme
    cardTheme: const CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Enhanced Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: darkOnSurface,
      ),
    ),
    
    // Enhanced Button Themes
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    
    // Enhanced Input Decoration
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: error, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    
    // Enhanced App Bar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: darkSurface,
      foregroundColor: darkOnSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: darkOnSurface,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    
    // Enhanced Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 3,
      backgroundColor: darkSurface,
      selectedItemColor: primary,
      unselectedItemColor: darkOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    ),
  );
}