import 'package:flutter/material.dart';

/// HireIQ Design System — Color Tokens
/// Every screen reads colors from here. Zero hardcoded hex elsewhere.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────
  static const Color violet = Color(0xFF7C5CFC);
  static const Color violetLt = Color(0xFF9B82FF);
  static const Color violetDk = Color(0xFF5B3FD4);
  static const Color cyan = Color(0xFF00D4FF);
  static const Color cyanDk = Color(0xFF00A8CC);
  static const Color emerald = Color(0xFF00E5A0);
  static const Color amber = Color(0xFFFFB930);
  static const Color rose = Color(0xFFFF4D6D);
  static const darkInk60 = Color(0x99E5E7EB);
  static const lightInk60 = Color(0x991F2937);

  // ── Dark surfaces ──────────────────────────────────────────
  static const Color darkBg = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF111118);
  static const Color darkSurface2 = Color(0xFF1A1A24);
  static const Color darkSurface3 = Color(0xFF222230);
  static const Color darkBorder = Color(0x12FFFFFF); // 7 %
  static const Color darkBorder2 = Color(0x1FFFFFFF); // 12%

  // ── Light surfaces ─────────────────────────────────────────
  static const Color lightBg = Color(0xFFF5F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0F0F8);
  static const Color lightSurface3 = Color(0xFFE8E8F0);
  static const Color lightBorder = Color(0x1A000000); // 10%
  static const Color lightBorder2 = Color(0x26000000); // 15%

  // ── Text (theme-independent helpers via ThemeExtension) ────
  static const Color darkInk = Color(0xFFFFFFFF);
  static const Color darkInk70 = Color(0xB3FFFFFF);
  static const Color darkInk40 = Color(0x66FFFFFF);
  static const Color darkInk15 = Color(0x26FFFFFF);

  static const Color lightInk = Color(0xFF0A0A0F);
  static const Color lightInk70 = Color(0xB30A0A0F);
  static const Color lightInk40 = Color(0x660A0A0F);
  static const Color lightInk15 = Color(0x260A0A0F);
}
