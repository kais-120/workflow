// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const bg        = Color(0xFF06080F);
  static const surface   = Color(0xFF0C0E1A);
  static const card      = Color(0xFF131628);
  static const border    = Color(0x1AFFFFFF);

  // Brand
  static const primary   = Color(0xFFF5A623);   // electric yellow
  static const secondary = Color(0xFFE74C3C);   // red accent
  static const success   = Color(0xFF00D68F);
  static const warning   = Color.fromARGB(255, 255, 246, 74);
  static const danger    = Color(0xFFFF4D6D);
  static const info      = Color(0xFF4D9FFF);

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted     = Color(0x40FFFFFF);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary:    AppColors.primary,
        secondary:  AppColors.secondary,
        surface:    AppColors.surface,
        error:      AppColors.danger,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        const TextTheme(
          displayLarge:  TextStyle(color: AppColors.textPrimary),
          displayMedium: TextStyle(color: AppColors.textPrimary),
          bodyLarge:     TextStyle(color: AppColors.textPrimary),
          bodyMedium:    TextStyle(color: AppColors.textSecondary),
          bodySmall:     TextStyle(color: AppColors.textMuted),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// Reusable text styles with Syne (headings)
class AppText {
  static TextStyle heading(double size) => GoogleFonts.syne(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle label = GoogleFonts.syne(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 2,
  );
}
