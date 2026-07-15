import 'package:flutter/material.dart';

/// Glossy and modern design color system matching the mockup images.
class AppColors {
  // Default to light theme values matching the Home Screen mockup
  static Color primary = const Color(0xFF6B4EE6);
  static Color secondary = const Color(0xFF09E5C3);
  static Color background = const Color(0xFFF3F4F9);
  static Color surface = const Color(0xFFFFFFFF);
  static Color get surfaceWithOpacity => surface.withOpacity(0.7);
  static Color border = const Color(0xFFDCDDF0).withOpacity(0.8);

  // Typography Text Colors
  static Color textPrimary = const Color(0xFF1F1F3F);
  static Color textSecondary = const Color(0xFF7A7D9D);

  // Leitner Box Colors
  static const Color box1 = Color(0xFFFF7A1A); // Orange
  static const Color box2 = Color(0xFFFFB61A); // Yellow
  static const Color box3 = Color(0xFF17C964); // Green
  static const Color box4 = Color(0xFF1A9CFF); // Blue
  static const Color box5 = Color(0xFFC333FF); // Purple
  static const Color box6 = Color(0xFFFFD700); // Gold
  static const Color finished = Color(0xFFFFD700); // Gold

  // Course Border Statuses
  static const Color courseDownloaded = Color(0xFF17C964); // Green border
  static const Color courseNotDownloaded = Color(0xFFFFB61A); // Yellow border
  
  static const Color error = Color(0xFFE53935); // Accent Red

  /// Set the colors dynamically based on active theme
  static void setTheme(bool isDark) {
    if (isDark) {
      primary = const Color(0xFF6B4EE6);
      secondary = const Color(0xFF09E5C3);
      background = const Color(0xFF181837);
      surface = const Color(0xFF22224E);
      border = const Color(0xFF3F3F75).withOpacity(0.4);
      textPrimary = const Color(0xFFFFFFFF);
      textSecondary = const Color(0xFFB5B7D3);
    } else {
      primary = const Color(0xFF6B4EE6);
      secondary = const Color(0xFF09E5C3);
      background = const Color(0xFFF3F4F9);
      surface = const Color(0xFFFFFFFF);
      border = const Color(0xFFDCDDF0).withOpacity(0.8);
      textPrimary = const Color(0xFF1F1F3F);
      textSecondary = const Color(0xFF7A7D9D);
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
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      fontFamily: 'Vazirmatn',
      colorScheme: const ColorScheme.light().copyWith(
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
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
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
}
