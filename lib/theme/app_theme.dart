import 'package:flutter/material.dart';

/// BednBite brand theme — mirrors the React app's dark surface + indigo accent
/// and the purple→pink wordmark gradient.
class BrandColors {
  // Wordmark gradient: Bedn + gradient "Bite" (#6d4bff → #9333ea → #ec4899)
  static const Color gradStart = Color(0xFF6D4BFF);
  static const Color gradMid = Color(0xFF9333EA);
  static const Color gradEnd = Color(0xFFEC4899);

  static const Color page = Color(0xFF0B0B12); // near-black page bg
  static const Color surface = Color(0xFF15151F); // card surface
  static const Color border = Color(0xFF272733);
  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFFA1A1B5);
  static const Color textMuted = Color(0xFF6B6B80);
  static const Color indigo = Color(0xFF4F46E5); // bg-indigo-600
  static const Color indigoHover = Color(0xFF6366F1);
  static const Color danger = Color(0xFFF87171);

  static const LinearGradient wordmark = LinearGradient(
    colors: [gradStart, gradMid, gradEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: BrandColors.page,
      colorScheme: base.colorScheme.copyWith(
        primary: BrandColors.indigo,
        surface: BrandColors.surface,
        error: BrandColors.danger,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.page,
        hintStyle: const TextStyle(color: BrandColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BrandColors.indigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BrandColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BrandColors.danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.indigo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF312E81),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
