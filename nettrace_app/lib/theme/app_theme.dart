import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Theme Colors
  static const Color bg = Color(0xFF0B1220);
  static const Color panel = Color(0xFF121A2B);
  static const Color panel2 = Color(0xFF182238);
  static const Color border = Color(0xFF26314A);
  static const Color borderSoft = Color(0xFF1D2740);
  static const Color text = Color(0xFFE8ECF3);
  static const Color textDim = Color(0xFF8B95A8);
  static const Color textFaint = Color(0xFF5A6478);

  static const Color amber = Color(0xFFF0A202);
  static const Color amberDim = Color(0xFF4A3510);

  static const Color red = Color(0xFFE24B4A);
  static const Color redDim = Color(0xFF3D1A1A);

  static const Color green = Color(0xFF5DCAA5);
  static const Color greenDim = Color(0xFF12332B);

  static const Color cyan = Color(0xFF4FD1C5);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: amber,
      colorScheme: const ColorScheme.dark(
        primary: amber,
        secondary: cyan,
        surface: panel,
        background: bg,
        error: red,
      ),
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.inter(color: text, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: textDim, fontSize: 14),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        hintStyle: GoogleFonts.jetBrainsMono(color: textFaint, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: amber),
        ),
      ),
    );
  }

  static TextStyle monoStyle({
    Color color = textDim,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static TextStyle displayStyle({
    Color color = text,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return GoogleFonts.spaceGrotesk(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static TextStyle sansStyle({
    Color color = text,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }
}
