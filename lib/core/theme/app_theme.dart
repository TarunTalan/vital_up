import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Colors Palette
  static const Color primaryColor = Color(0xFF10B981); // Emerald Green
  static const Color primaryDarkColor = Color(0xFF047857);
  static const Color secondaryColor = Color(0xFF3B82F6); // Blue Accent
  static const Color accentColor = Color(0xFFF59E0B); // Amber Accent
  static const Color errorColor = Color(0xFFEF4444); // Red
  
  // Light Mode Colors
  static const Color lightBackgroundColor = Color(0xFFF9FAFB);
  static const Color lightSurfaceColor = Colors.white;
  static const Color lightOnBackgroundColor = Color(0xFF111827);
  static const Color lightOnSurfaceColor = Color(0xFF1F2937);

  // Dark Mode Colors
  static const Color darkBackgroundColor = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceColor = Color(0xFF1E293B); // Slate 800
  static const Color darkOnBackgroundColor = Color(0xFFF9FAFB);
  static const Color darkOnSurfaceColor = Color(0xFFF3F4F6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: lightSurfaceColor,
        onSurface: lightOnSurfaceColor,
      ),
      scaffoldBackgroundColor: lightBackgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: lightOnBackgroundColor,
        ),
        bodyLarge: GoogleFonts.inter(
          color: lightOnSurfaceColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurfaceColor,
        foregroundColor: lightOnBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: lightSurfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: darkSurfaceColor,
        onSurface: darkOnSurfaceColor,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: darkOnBackgroundColor,
        ),
        bodyLarge: GoogleFonts.inter(
          color: darkOnSurfaceColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkOnBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: darkSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
