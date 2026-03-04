import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HireIQ Typography — Syne (display) + DM Sans (body)
class AppTextStyles {
  AppTextStyles._();

  // ── Display / Headings (Syne) ───────────────────────────────
  static TextStyle displayLarge(Color color) => GoogleFonts.syne(
    fontSize: 32, fontWeight: FontWeight.w800,
    color: color, letterSpacing: -1.0,
  );

  static TextStyle displayMedium(Color color) => GoogleFonts.syne(
    fontSize: 24, fontWeight: FontWeight.w800,
    color: color, letterSpacing: -0.6,
  );

  static TextStyle displaySmall(Color color) => GoogleFonts.syne(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: color, letterSpacing: -0.4,
  );

  static TextStyle title(Color color) => GoogleFonts.syne(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: color, letterSpacing: -0.2,
  );

  static TextStyle label(Color color) => GoogleFonts.syne(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: color, letterSpacing: 0.8,
  );

  static TextStyle navLabel(Color color) => GoogleFonts.syne(
    fontSize: 10, fontWeight: FontWeight.w600,
    color: color, letterSpacing: 0.3,
  );

  // ── Body (DM Sans) ──────────────────────────────────────────
  static TextStyle bodyLarge(Color color) => GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: color,
  );

  static TextStyle bodyMedium(Color color) => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: color,
  );

  static TextStyle bodySmall(Color color) => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w400, color: color,
  );

  static TextStyle bodyMediumSemiBold(Color color) => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w600, color: color,
  );

  static TextStyle caption(Color color) => GoogleFonts.dmSans(
    fontSize: 11, fontWeight: FontWeight.w400, color: color,
  );
}
