import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  MEDIVAANII — Monochrome (Black, White & Grays)
//  Primary: #1A1A1A   Mid: #4A4A4A   Light: #F5F5F5
// ══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  static const gray900  = Color(0xFF1A1A1A);  // near black
  static const gray800  = Color(0xFF2E2E2E);  // app bar
  static const gray700  = Color(0xFF3D3D3D);  // primary buttons
  static const gray600  = Color(0xFF4A4A4A);  // text primary
  static const gray500  = Color(0xFF6B6B6B);  // icons, secondary
  static const gray400  = Color(0xFF909090);  // muted text
  static const gray300  = Color(0xFFB8B8B8);  // borders
  static const gray200  = Color(0xFFD8D8D8);  // dividers
  static const gray100  = Color(0xFFEEEEEE);  // light bg
  static const gray50   = Color(0xFFF5F5F5);  // page bg

  static const bg       = Color(0xFFF5F5F5);
  static const surface  = Color(0xFFFFFFFF);
  static const border   = Color(0xFFD8D8D8);
  static const divider  = Color(0xFFEEEEEE);

  static const success  = Color(0xFF2E7D32);
  static const successBg= Color(0xFFE8F5E9);
  static const red      = Color(0xFFC62828);
  static const redBg    = Color(0xFFFFEBEE);
  static const amber    = Color(0xFFE65100);
  static const amberBg  = Color(0xFFFFF3E0);

  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF4A4A4A);
  static const textMuted     = Color(0xFF909090);

  // Aliases for existing code
  static const navy900 = gray900;
  static const navy800 = gray700;
  static const navy700 = gray700;
  static const navy600 = gray600;
  static const navy400 = gray400;
  static const navy200 = gray200;
  static const navy100 = gray100;
  static const navy50  = gray50;
  static const blue800 = gray700;
  static const blue900 = gray900;
  static const blue50  = gray50;
  static const blue100 = gray100;
  static const blue200 = gray200;
  static const blue400 = gray400;
  static const accent  = gray700;
  static const accentBg= gray100;
  static const gold600 = gray700;
  static const gold100 = gray100;
  static const error   = red;
}

class MediSimpleTheme {
  MediSimpleTheme._();
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.gray700,
      onPrimary: Colors.white,
      primaryContainer: AppColors.gray100,
      secondary: AppColors.gray500,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.gray900,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 66,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: Colors.white, letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.gray100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
        fontSize: 11,
        fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        color: s.contains(WidgetState.selected) ? AppColors.gray900 : AppColors.textMuted,
      )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? AppColors.gray900 : AppColors.textMuted,
        size: 22,
      )),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gray900,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gray900,
        side: const BorderSide(color: AppColors.gray300, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.gray100,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gray700),
      side: const BorderSide(color: AppColors.gray300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.gray900,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gray700,
      linearTrackColor: AppColors.gray100,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AppColors.gray300),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.gray700 : AppColors.gray200),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

class APColors {
  static const primary      = AppColors.gray700;
  static const primaryDark  = AppColors.gray900;
  static const primaryLight = AppColors.gray50;
  static const secondary    = AppColors.gray500;
  static const surface      = AppColors.surface;
  static const background   = AppColors.bg;
  static const error        = AppColors.red;
}
