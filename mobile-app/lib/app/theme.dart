import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HSL-derived color tokens defined in ui_design.md.
class AppColors {
  static const Color primary = Color(0xFF8F53FF);      // HSL(263, 90%, 65%)
  static const Color secondary = Color(0xFF09E5C3);    // HSL(174, 90%, 45%)
  static const Color background = Color(0xFF121620);   // HSL(222, 25%, 10%)
  static const Color surface = Color(0xFF1A2130);      // HSLA(223, 20%, 15%, 0.7) (Fallback surface color)
  static final Color surfaceWithOpacity = const Color(0xFF1A2130).withOpacity(0.7);
  static final Color border = const Color(0xFF333E56).withOpacity(0.4); // HSLA(223, 15%, 25%, 0.4)

  // Typography Text Colors
  static const Color textPrimary = Color(0xFFF3F6FA);   // HSL(210, 40%, 98%)
  static const Color textSecondary = Color(0xFFB8C1CD); // HSL(215, 20%, 75%)

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
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        displayMedium: GoogleFonts.outfit(
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        displaySmall: GoogleFonts.outfit(
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        bodyLarge: GoogleFonts.inter(
          textStyle: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        bodyMedium: GoogleFonts.inter(
          textStyle: const TextStyle(
            color: AppColors.textSecondary,
          ),
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
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
