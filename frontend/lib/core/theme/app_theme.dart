// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 28.0;

  // ── Deep Space Dark ────────────────────────────────────────────
  // Signature look: deep navy background, violet/cyan glass cards
  static const _darkBg = Color(0xFF080D1A); // near-black navy
  static const _darkSurface = Color(0xFF0F1729); // card surface
  static const _darkSurf2 = Color(0xFF151E35); // elevated surface
  static const _darkBorder = Color(0xFF1E2D4A); // subtle border
  static const _darkInk = Color(0xFFE8EFFF); // primary text
  static const _darkSubtle = Color(0xFF7A8AAD); // secondary text

  // ── Pearl Light ───────────────────────────────────────────────
  // Clean, airy: warm white with violet depth
  static const _lightBg = Color(0xFFF4F7FF); // pearl white
  static const _lightSurface = Color(0xFFFFFFFF); // pure white cards
  static const _lightSurf2 = Color(0xFFEEF1FB); // tinted surface
  static const _lightBorder = Color(0xFFDDE3F5); // light border
  static const _lightInk = Color(0xFF0D1226); // near black
  static const _lightSubtle = Color(0xFF6B7A99); // secondary

  // ── System chrome overlays ────────────────────────────────────
  static SystemUiOverlayStyle get darkOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // white icons
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: _darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      );

  static SystemUiOverlayStyle get lightOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // dark icons
        statusBarBrightness: Brightness.light, // iOS
        systemNavigationBarColor: _lightBg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      );

  // ── Text theme helper ─────────────────────────────────────────
  static TextTheme _textTheme(Color ink, Color subtle) {
    // Noto Sans Arabic — beautiful, works for AR + EN
    final base = GoogleFonts.notoSansArabicTextTheme().copyWith(
      displayLarge: GoogleFonts.notoSansArabic(
          fontSize: 57, fontWeight: FontWeight.w900, color: ink),
      displayMedium: GoogleFonts.notoSansArabic(
          fontSize: 45, fontWeight: FontWeight.w800, color: ink),
      displaySmall: GoogleFonts.notoSansArabic(
          fontSize: 36, fontWeight: FontWeight.w700, color: ink),
      headlineLarge: GoogleFonts.notoSansArabic(
          fontSize: 32, fontWeight: FontWeight.w800, color: ink),
      headlineMedium: GoogleFonts.notoSansArabic(
          fontSize: 26, fontWeight: FontWeight.w700, color: ink),
      headlineSmall: GoogleFonts.notoSansArabic(
          fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      titleLarge: GoogleFonts.notoSansArabic(
          fontSize: 18, fontWeight: FontWeight.w800, color: ink),
      titleMedium: GoogleFonts.notoSansArabic(
          fontSize: 16, fontWeight: FontWeight.w700, color: ink),
      titleSmall: GoogleFonts.notoSansArabic(
          fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: GoogleFonts.notoSansArabic(
          fontSize: 16, fontWeight: FontWeight.w400, color: ink, height: 1.6),
      bodyMedium: GoogleFonts.notoSansArabic(
          fontSize: 14, fontWeight: FontWeight.w400, color: ink, height: 1.5),
      bodySmall: GoogleFonts.notoSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: subtle,
          height: 1.5),
      labelLarge: GoogleFonts.notoSansArabic(
          fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      labelMedium: GoogleFonts.notoSansArabic(
          fontSize: 12, fontWeight: FontWeight.w600, color: subtle),
      labelSmall: GoogleFonts.notoSansArabic(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: subtle,
          letterSpacing: 0.8),
    );
    return base;
  }

  // ════════════════════════════════════════════════════════════════
  // DARK THEME
  // ════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkBg,

        colorScheme: const ColorScheme.dark(
          primary: AppColors.violet,
          primaryContainer: Color(0xFF1E1040),
          secondary: AppColors.cyan,
          secondaryContainer: Color(0xFF0A2230),
          tertiary: AppColors.emerald,
          surface: _darkSurface,
          surfaceContainerHighest: _darkSurf2,
          error: AppColors.rose,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: _darkInk,
          onError: Colors.white,
          outline: _darkBorder,
          outlineVariant: Color(0xFF1A2540),
          shadow: Color(0xFF000000),
          scrim: Color(0x80000000),
        ),

        textTheme: _textTheme(_darkInk, _darkSubtle),

        // ── AppBar ────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _darkInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: darkOverlay,
          titleTextStyle: GoogleFonts.notoSansArabic(
              fontSize: 20, fontWeight: FontWeight.w800, color: _darkInk),
        ),

        // ── Cards ─────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
              side: const BorderSide(color: _darkBorder, width: 1)),
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
        ),

        // ── Buttons ───────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _darkBorder,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg)),
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.violet,
            side: const BorderSide(color: AppColors.violet, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg)),
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.violet,
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),

        // ── Input ─────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSurface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: _darkBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: _darkBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: AppColors.violet, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: AppColors.rose)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: _darkSubtle, fontSize: 14),
          labelStyle: const TextStyle(color: _darkSubtle),
        ),

        // ── Bottom Nav ────────────────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _darkSurface,
          selectedItemColor: AppColors.violet,
          unselectedItemColor: _darkSubtle,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),

        // ── Divider ───────────────────────────────────────────────────
        dividerTheme:
            const DividerThemeData(color: _darkBorder, thickness: 1, space: 1),

        // ── Snack bar ─────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _darkSurf2,
          contentTextStyle:
              GoogleFonts.notoSansArabic(color: _darkInk, fontSize: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Dialog ────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius2xl),
              side: const BorderSide(color: _darkBorder)),
        ),

        // ── Chip ─────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: _darkSurf2,
          selectedColor: AppColors.violet.withValues(alpha: 0.2),
          labelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w600, color: _darkInk),
          side: const BorderSide(color: _darkBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // ── Switch ────────────────────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : _darkSubtle),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.violet
                  : _darkBorder),
        ),

        // ── Progress ──────────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.violet,
          linearTrackColor: _darkBorder,
          circularTrackColor: _darkBorder,
          refreshBackgroundColor: _darkSurface,
        ),

        // ── List tile ─────────────────────────────────────────────────
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          iconColor: _darkSubtle,
          textColor: _darkInk,
          dense: false,
        ),

        // ── Tab bar ───────────────────────────────────────────────────
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.violet,
          unselectedLabelColor: _darkSubtle,
          indicatorColor: AppColors.violet,
          labelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w500),
          dividerColor: _darkBorder,
        ),

        // ── Icon ─────────────────────────────────────────────────────
        iconTheme: const IconThemeData(color: _darkSubtle, size: 24),
        primaryIconTheme: const IconThemeData(color: AppColors.violet),
      );

  // ════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.violet,
          primaryContainer: Color(0xFFEDE8FF),
          secondary: AppColors.cyan,
          secondaryContainer: Color(0xFFD6F4FF),
          tertiary: AppColors.emerald,
          surface: _lightSurface,
          surfaceContainerHighest: _lightSurf2,
          error: AppColors.rose,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: _lightInk,
          onError: Colors.white,
          outline: _lightBorder,
          outlineVariant: Color(0xFFCDD5EC),
        ),
        textTheme: _textTheme(_lightInk, _lightSubtle),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _lightInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: lightOverlay,
          titleTextStyle: GoogleFonts.notoSansArabic(
              fontSize: 20, fontWeight: FontWeight.w800, color: _lightInk),
        ),
        cardTheme: CardThemeData(
          color: _lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),
              side: const BorderSide(color: _lightBorder, width: 1)),
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _lightBorder,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg)),
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.violet,
            side: const BorderSide(color: AppColors.violet, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg)),
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.violet,
            textStyle: GoogleFonts.notoSansArabic(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lightSurface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: _lightBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: _lightBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: AppColors.violet, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              borderSide: const BorderSide(color: AppColors.rose)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: _lightSubtle, fontSize: 14),
          labelStyle: const TextStyle(color: _lightSubtle),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _lightSurface,
          selectedItemColor: AppColors.violet,
          unselectedItemColor: _lightSubtle,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme:
            const DividerThemeData(color: _lightBorder, thickness: 1, space: 1),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _lightInk,
          contentTextStyle:
              GoogleFonts.notoSansArabic(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius2xl),
              side: const BorderSide(color: _lightBorder)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _lightSurf2,
          selectedColor: AppColors.violet.withValues(alpha: 0.12),
          labelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w600, color: _lightInk),
          side: const BorderSide(color: _lightBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : _lightSubtle),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.violet
                  : _lightBorder),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.violet,
          linearTrackColor: _lightBorder,
          circularTrackColor: _lightBorder.withValues(alpha: 0.5),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          iconColor: _lightSubtle,
          textColor: _lightInk,
          dense: false,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.violet,
          unselectedLabelColor: _lightSubtle,
          indicatorColor: AppColors.violet,
          labelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.notoSansArabic(
              fontSize: 12, fontWeight: FontWeight.w500),
          dividerColor: _lightBorder,
        ),
        iconTheme: const IconThemeData(color: _lightSubtle, size: 24),
        primaryIconTheme: const IconThemeData(color: AppColors.violet),
      );

  // ── Convenience getters for manual use in widgets ─────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Background colors accessible without hardcoding in widgets
  static Color bgColor(BuildContext context) =>
      isDark(context) ? _darkBg : _lightBg;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? _darkSurface : _lightSurface;

  static Color surface2Color(BuildContext context) =>
      isDark(context) ? _darkSurf2 : _lightSurf2;

  static Color borderColor(BuildContext context) =>
      isDark(context) ? _darkBorder : _lightBorder;

  static Color inkColor(BuildContext context) =>
      isDark(context) ? _darkInk : _lightInk;

  static Color subtleColor(BuildContext context) =>
      isDark(context) ? _darkSubtle : _lightSubtle;
}
