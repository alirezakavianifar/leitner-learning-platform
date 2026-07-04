import 'package:flutter/material.dart';

/// HSL-derived color tokens defined in ui_design.md.
class AppColors {
  static Color primary = const Color(0xFF8F53FF);      // HSL(263, 90%, 65%)
  static Color secondary = const Color(0xFF09E5C3);    // HSL(174, 90%, 45%)
  static Color background = const Color(0xFF121620);   // HSL(222, 25%, 10%)
  static Color surface = const Color(0xFF1A2130);      // HSLA(223, 20%, 15%, 0.7) (Fallback surface color)
  static Color get surfaceWithOpacity => surface.withOpacity(0.7);
  static Color border = const Color(0xFF333E56).withOpacity(0.4); // HSLA(223, 15%, 25%, 0.4)

  // Typography Text Colors
  static Color textPrimary = const Color(0xFFF3F6FA);   // HSL(210, 40%, 98%)
  static Color textSecondary = const Color(0xFFB8C1CD); // HSL(215, 20%, 75%)

  // Leitner Box Colors
  static const Color box1 = Color(0xFFFF7A1A); // Orange
  static const Color box2 = Color(0xFFFFB61A); // Yellow
  static const Color box3 = Color(0xFF17C964); // Green
  static const Color box4 = Color(0xFF1A9CFF); // Blue
  static const Color box5 = Color(0xFFC333FF); // Purple
  static const Color finished = Color(0xFFFFD700); // Gold

  // Course Border Statuses
  static const Color courseDownloaded = Color(0xFF17C964); // Green border
  static const Color courseNotDownloaded = Color(0xFFFFB61A); // Yellow border
  
  static const Color error = Color(0xFFE53935); // Accent Red

  /// Set the colors dynamically based on active theme
  static void setTheme(bool isDark) {
    if (isDark) {
      primary = const Color(0xFF8F53FF);
      secondary = const Color(0xFF09E5C3);
      background = const Color(0xFF121620);
      surface = const Color(0xFF1A2130);
      border = const Color(0xFF333E56).withOpacity(0.4);
      textPrimary = const Color(0xFFF3F6FA);
      textSecondary = const Color(0xFFB8C1CD);
    } else {
      primary = const Color(0xFF8F53FF);
      secondary = const Color(0xFF09E5C3);
      background = const Color(0xFFF5F6FA); // Soft light gray background
      surface = const Color(0xFFFFFFFF);    // Card surface
      border = const Color(0xFFCBD5E1).withOpacity(0.6); // Slate 300
      textPrimary = const Color(0xFF1E293B);   // Slate 800
      textSecondary = const Color(0xFF64748B); // Slate 500
    }
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      fontFamily: 'Vazirmatn',
      colorScheme: const ColorScheme.dark().copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textSecondary,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWithOpacity,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWithOpacity,
        hintStyle: TextStyle(color: AppColors.textSecondary),
        labelStyle: TextStyle(color: AppColors.textPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      primaryColor: const Color(0xFF8F53FF),
      fontFamily: 'Vazirmatn',
      colorScheme: const ColorScheme.light().copyWith(
        primary: const Color(0xFF8F53FF),
        secondary: const Color(0xFF09E5C3),
        background: const Color(0xFFF5F6FA),
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFE53935),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFF64748B),
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF64748B),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFCBD5E1).withOpacity(0.6), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        labelStyle: const TextStyle(color: Color(0xFF1E293B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8F53FF), width: 2),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF8F53FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
