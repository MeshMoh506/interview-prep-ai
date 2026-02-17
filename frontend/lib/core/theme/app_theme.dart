import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 30.0;

  // ── Convenience getters used by older pages ──────────────────────
  // (These bridge the old AppTheme.primary / AppTheme.bg / etc. API)
  static Color get primary     => AppColors.violet;
  static Color get bg          => AppColors.darkBg;
  static Color get surface     => AppColors.darkSurface;
  static Color get ink         => AppColors.darkInk;
  static Color get inkMid      => AppColors.darkInk70;
  static Color get inkLight    => AppColors.darkInk40;
  static Color get line        => AppColors.darkBorder;
  static Color get elevate1    => AppColors.darkSurface2;
  static Color get success     => AppColors.emerald;
  static Color get warning     => AppColors.amber;
  static Color get danger      => AppColors.rose;
  static Color get background  => AppColors.darkBg;
  static Color get textDark    => AppColors.darkInk;
  static Color get textLight   => AppColors.darkInk40;
  static Color get error       => AppColors.rose;
  static List<Color> get brandGrad    => [AppColors.violet, AppColors.violetDk];
  static List<Color> get glowPrimary  => [AppColors.violet.withValues(alpha: 0.4),
                                           AppColors.violet.withValues(alpha: 0.0)];

  // ════════════════════════════════════════════════════════════════
  // DARK THEME
  // ════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    const bg      = AppColors.darkBg;
    const surface = AppColors.darkSurface;
    const ink     = AppColors.darkInk;
    const ink70   = AppColors.darkInk70;
    const ink40   = AppColors.darkInk40;
    const border  = AppColors.darkBorder;

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,

      colorScheme: const ColorScheme.dark(
        primary:     AppColors.violet,
        secondary:   AppColors.cyan,
        tertiary:    AppColors.emerald,
        surface:     surface,
        error:       AppColors.rose,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   ink,
        onError:     Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 22, fontWeight: FontWeight.w800,
          color: ink, letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: ink, size: 22),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.syne(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink70,
          side: const BorderSide(color: AppColors.darkBorder2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violetLt,
          textStyle: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: ink40, fontSize: 14),
        labelStyle: GoogleFonts.syne(
          color: ink40, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6,
        ),
        floatingLabelStyle: GoogleFonts.syne(
          color: AppColors.violetLt, fontSize: 12, fontWeight: FontWeight.w600,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.violetLt,
        unselectedItemColor: ink40,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface2,
        selectedColor: const Color(0x1E7C5CFC),
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.syne(
          fontSize: 12, fontWeight: FontWeight.w600, color: ink70,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.syne(
          fontSize: 18, fontWeight: FontWeight.w700, color: ink,
        ),
        contentTextStyle: GoogleFonts.dmSans(fontSize: 14, color: ink70),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface2,
        contentTextStyle: GoogleFonts.dmSans(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: AppColors.darkBorder2),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violet,
        linearTrackColor: AppColors.darkSurface3,
        circularTrackColor: AppColors.darkSurface3,
      ),

      iconTheme: const IconThemeData(color: ink70, size: 22),

      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge:  GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: ink, letterSpacing: -1.0),
        displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.6),
        headlineLarge: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.5),
        headlineMedium:GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        titleLarge:    GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
        titleMedium:   GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
        bodyLarge:     GoogleFonts.dmSans(fontSize: 16, color: ink70),
        bodyMedium:    GoogleFonts.dmSans(fontSize: 14, color: ink70),
        bodySmall:     GoogleFonts.dmSans(fontSize: 12, color: ink40),
        labelLarge:    GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        labelSmall:    GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600, color: ink40, letterSpacing: 0.5),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    const bg      = AppColors.lightBg;
    const surface = AppColors.lightSurface;
    const ink     = AppColors.lightInk;
    const ink70   = AppColors.lightInk70;
    const ink40   = AppColors.lightInk40;
    const border  = AppColors.lightBorder;

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,

      colorScheme: const ColorScheme.light(
        primary:     AppColors.violet,
        secondary:   AppColors.cyan,
        tertiary:    AppColors.emerald,
        surface:     surface,
        error:       AppColors.rose,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   ink,
        onError:     Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 22, fontWeight: FontWeight.w800,
          color: ink, letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: ink, size: 22),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink70,
          side: const BorderSide(color: AppColors.lightBorder2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violet,
          textStyle: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: ink40, fontSize: 14),
        labelStyle: GoogleFonts.syne(
          color: ink40, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6,
        ),
        floatingLabelStyle: GoogleFonts.syne(
          color: AppColors.violet, fontSize: 12, fontWeight: FontWeight.w600,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.violet,
        unselectedItemColor: ink40,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface2,
        selectedColor: const Color(0x157C5CFC),
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w600, color: ink70),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        contentTextStyle: GoogleFonts.dmSans(fontSize: 14, color: ink70),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.dmSans(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: AppColors.lightBorder2),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violet,
        linearTrackColor: AppColors.lightSurface3,
        circularTrackColor: AppColors.lightSurface3,
      ),

      iconTheme: const IconThemeData(color: ink70, size: 22),

      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge:  GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: ink, letterSpacing: -1.0),
        displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.6),
        headlineLarge: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.5),
        headlineMedium:GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        titleLarge:    GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
        titleMedium:   GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
        bodyLarge:     GoogleFonts.dmSans(fontSize: 16, color: ink70),
        bodyMedium:    GoogleFonts.dmSans(fontSize: 14, color: ink70),
        bodySmall:     GoogleFonts.dmSans(fontSize: 12, color: ink40),
        labelLarge:    GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        labelSmall:    GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w600, color: ink40, letterSpacing: 0.5),
      ),
    );
  }
}
