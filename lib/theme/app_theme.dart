import 'package:flutter/material.dart';

/// Palet warna aplikasi.
///
/// Nilainya bisa berubah saat runtime: aksen mengikuti warna sistem
/// (Material You) dan latar bisa dibuat hitam pekat (AMOLED).
class AppColors {
  // Kanvas gelap ala Material Expressive.
  static Color bg = const Color(0xFF0D0F14);
  static Color card = const Color(0xFF171A21);
  static Color cardHigh = const Color(0xFF232833);
  static Color divider = const Color(0xFF2B303B);

  // Aksen (mengikuti sistem kalau tersedia).
  static Color primary = const Color(0xFFAFC2FF);
  static Color onPrimary = const Color(0xFF0C1533);
  static Color accent = const Color(0xFF1B54E0);
  static Color accentSoft = const Color(0xFF243B7A);
  static Color pill = const Color(0xFF1E2531);
  static Color logo = const Color(0xFF3D7BFF);

  static const Color text = Color(0xFFEDEFF5);
  static const Color muted = Color(0xFF9BA3B2);
  static const Color danger = Color(0xFFFF8A8A);

  static const Color archives = Color(0xFFD3A379);
  static const Color videos = Color(0xFFE97BA0);
  static const Color apps = Color(0xFF8CCBA6);
  static const Color images = Color(0xFFB2A4F2);
  static const Color audio = Color(0xFF74C2E4);
  static const Color documents = Color(0xFFE7C367);
  static const Color other = Color(0xFF9AA0AC);

  static const Color defaultSeed = Color(0xFF3D7BFF);

  static Color get seed => _seed;
  static Color _seed = defaultSeed;

  /// Terapkan aksen sistem + mode AMOLED.
  static void apply({Color? seedColor, bool amoled = false}) {
    _seed = seedColor ?? defaultSeed;

    primary = Color.lerp(_seed, Colors.white, 0.62)!;
    onPrimary = Color.lerp(Colors.black, _seed, 0.22)!;
    accent = _seed;
    accentSoft = Color.lerp(_seed, Colors.black, 0.45)!;
    logo = _seed;

    if (amoled) {
      bg = Colors.black;
      card = const Color(0xFF08080A);
      cardHigh = const Color(0xFF121216);
      divider = const Color(0xFF1C1C22);
      pill = const Color(0xFF141418);
    } else {
      bg = const Color(0xFF0D0F14);
      card = const Color(0xFF171A21);
      cardHigh = const Color(0xFF232833);
      divider = const Color(0xFF2B303B);
      pill = const Color(0xFF1E2531);
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.accent,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.logo,
    onSecondary: Colors.white,
    tertiary: AppColors.images,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.cardHigh,
    outline: AppColors.divider,
    error: AppColors.danger,
    onError: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Roboto',
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardHigh,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.cardHigh,
        disabledForegroundColor: AppColors.muted,
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cardHigh,
      contentTextStyle: const TextStyle(color: AppColors.text),
      actionTextColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Predictive back gesture di Android 14+ (fallback ke zoom).
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.pill,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          )),
    ),
  );
}
