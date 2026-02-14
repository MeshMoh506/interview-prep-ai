// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── NEW Palette ───────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color bg = Color(0xFFF0F2FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F0F23);
  static const Color inkMid = Color(0xFF4B5563);
  static const Color inkLight = Color(0xFF9CA3AF);
  static const Color line = Color(0xFFE5E7EB);

  // ── BACKWARD-COMPAT aliases (old names used by resume/interview pages) ──
  static const Color error = danger;
  static const Color background = bg;
  static const Color textDark = ink;
  static const Color textLight = inkLight;
  static const Color textMid = inkMid;

  // Gradients
  static const LinearGradient brandGrad = LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient heroGrad = LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.5, 1.0]);

  // Shadows
  static List<BoxShadow> get elevate1 => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1)),
      ];
  static List<BoxShadow> get elevate2 => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get glowPrimary => [
        BoxShadow(
            color: primary.withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 8)),
        BoxShadow(
            color: primary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ];
  // Old alias used by some pages
  static List<BoxShadow> get cardShadow => elevate1;

  // ── Light Theme ──────────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: accent,
          surface: surface,
          error: danger),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: bg,
          foregroundColor: ink,
          systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark),
          titleTextStyle: TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1))),
      cardTheme: CardThemeData(
          elevation: 0,
          color: surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: line))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primary, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: danger, width: 2)),
          labelStyle: const TextStyle(color: inkLight, fontSize: 14),
          hintStyle: const TextStyle(color: inkLight, fontSize: 14)),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          elevation: 0,
          height: 64,
          indicatorColor: primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? primary : inkLight)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? primary : inkLight,
              size: 22))),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  // Backward-compat alias
  static ThemeData get lightTheme => light;
}
