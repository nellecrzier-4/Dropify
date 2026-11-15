import 'package:flutter/material.dart';

import '../widgets/motion.dart';

/// Tampilan aplikasi (Material You).
///
/// Warna diturunkan dari satu seed: warna sistem kalau "dynamic color" aktif,
/// kalau tidak memakai seed bawaan. [light] dan [dark] mengikuti skema M3,
/// [amoled] memakai kanvas hitam pekat dengan permukaan tonal yang sama.
enum AppAppearance { light, dark, amoled }

/// Palet & token Material You untuk seluruh aplikasi.
class AppColors {
  static AppAppearance appearance = AppAppearance.light;

  static bool get isDark => appearance != AppAppearance.light;
  static bool get isAmoled => appearance == AppAppearance.amoled;

  /// Skema M3 aktif — sumber semua warna di bawah.
  static late ColorScheme scheme;

  // ---- Kanvas -------------------------------------------------------------
  static Color bg = const Color(0xFFFCF8FF);
  static Color bgTop = const Color(0xFFFCF8FF);
  static Color bgBottom = const Color(0xFFF3EDFB);

  /// Wash warna lembut di latar (turunan primary/secondary/tertiary).
  static Color washA = const Color(0x1F6750A4);
  static Color washB = const Color(0x14625B71);
  static Color washC = const Color(0x147D5262);

  // ---- Permukaan ----------------------------------------------------------
  static Color card = const Color(0xFFF7F2FA);
  static Color cardHigh = const Color(0xFFECE6F0);
  static Color divider = const Color(0xFFCAC4D0);
  static Color border = const Color(0x1F49454F);

  static Color glassFill = const Color(0xB3ECE6F0);
  static Color glassStroke = const Color(0xFFCAC4D0);

  /// Panel tonal (dulu panel gelap glossy) — sekarang primary container M3.
  static Color heroTop = const Color(0xFFEADDFF);
  static Color heroBottom = const Color(0xFFEADDFF);

  // ---- Aksen --------------------------------------------------------------
  static Color primary = const Color(0xFF6750A4);
  static Color onPrimary = const Color(0xFFFFFFFF);
  static Color accent = const Color(0xFF6750A4);
  static Color accentSoft = const Color(0xFFEADDFF);
  static Color accentText = const Color(0xFF6750A4);
  static Color pill = const Color(0xFFECE6F0);
  static Color logo = const Color(0xFF6750A4);

  // ---- Teks ---------------------------------------------------------------
  static Color text = const Color(0xFF1D1B20);
  static Color muted = const Color(0xFF49454F);
  static Color mutedStrong = const Color(0xFF322F35);
  static Color danger = const Color(0xFFB3261E);

  // ---- Kategori file ------------------------------------------------------
  static Color archives = const Color(0xFF8A6A3B);
  static Color videos = const Color(0xFF9C4A6B);
  static Color apps = const Color(0xFF3B6B4E);
  static Color images = const Color(0xFF6650A4);
  static Color audio = const Color(0xFF3F5F80);
  static Color documents = const Color(0xFF7A5C1E);
  static Color other = const Color(0xFF5D5B66);

  // Tanpa warna sistem, tema utama Dropify memakai biru.
  static const Color defaultSeed = Color(0xFF0A84FF);

  static Color get seed => _seed;
  static Color _seed = defaultSeed;

  /// Terapkan aksen (biasanya warna sistem) + tampilan.
  static void apply({Color? seedColor, AppAppearance? appearance}) {
    _seed = seedColor ?? defaultSeed;
    if (appearance != null) AppColors.appearance = appearance;

    final dark = isDark;
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: dark ? Brightness.dark : Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    // AMOLED: kanvas hitam, permukaan dibuat sedikit lebih gelap.
    final schemeSurface = isAmoled ? Colors.black : base.surface;
    scheme = isAmoled
        ? base.copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: const Color(0xFF0E0D11),
            surfaceContainer: const Color(0xFF141318),
            surfaceContainerHigh: const Color(0xFF1C1B21),
            surfaceContainerHighest: const Color(0xFF26252B),
          )
        : base;

    bg = schemeSurface;
    bgTop = isAmoled ? Colors.black : scheme.surface;
    bgBottom = isAmoled ? Colors.black : scheme.surfaceContainerLowest;

    card = scheme.surfaceContainerLow;
    cardHigh = scheme.surfaceContainerHigh;
    divider = scheme.outlineVariant;
    border = scheme.outlineVariant.withValues(alpha: dark ? 0.55 : 0.75);
    glassFill = scheme.surfaceContainerHigh.withValues(alpha: dark ? 0.72 : 0.82);
    glassStroke = scheme.outlineVariant.withValues(alpha: dark ? 0.5 : 0.8);

    primary = scheme.primary;
    onPrimary = scheme.onPrimary;
    accent = scheme.primary;
    accentSoft = scheme.primaryContainer;
    accentText = scheme.primary;
    pill = scheme.surfaceContainerHigh;
    logo = scheme.primary;

    heroTop = scheme.primaryContainer;
    heroBottom = scheme.primaryContainer;

    text = scheme.onSurface;
    muted = scheme.onSurfaceVariant;
    mutedStrong = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.82),
      scheme.surface,
    );
    danger = scheme.error;

    washA = scheme.primary.withValues(alpha: dark ? 0.16 : 0.10);
    washB = scheme.secondary.withValues(alpha: dark ? 0.12 : 0.07);
    washC = scheme.tertiary.withValues(alpha: dark ? 0.12 : 0.07);

    // Warna kategori: hue tetap, diselaraskan ke skema aktif.
    Color cat(Color base, Color tint) => Color.lerp(base, tint, 0.10)!;
    if (dark) {
      archives = cat(const Color(0xFFE6B577), scheme.primary);
      videos = cat(const Color(0xFFF08FAF), scheme.primary);
      apps = cat(const Color(0xFF84D6A6), scheme.primary);
      images = cat(const Color(0xFFC4B2FF), scheme.primary);
      audio = cat(const Color(0xFF8FC6EA), scheme.primary);
      documents = cat(const Color(0xFFE3C878), scheme.primary);
      other = scheme.onSurfaceVariant;
    } else {
      archives = cat(const Color(0xFF8A6A3B), scheme.primary);
      videos = cat(const Color(0xFF9C4A6B), scheme.primary);
      apps = cat(const Color(0xFF3B6B4E), scheme.primary);
      images = cat(const Color(0xFF6650A4), scheme.primary);
      audio = cat(const Color(0xFF3F5F80), scheme.primary);
      documents = cat(const Color(0xFF7A5C1E), scheme.primary);
      other = scheme.onSurfaceVariant;
    }
  }

  // ---- Bayangan (dipakai hemat — M3 memakai tonal, bukan bayangan tebal) ---
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.07),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
          blurRadius: 44,
          offset: const Offset(0, 20),
        ),
      ];

  /// Glow aksen lembut untuk elemen yang sedang aktif/selected.
  static List<BoxShadow> glow(Color color, {double blur = 24, double y = 8}) => [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.30 : 0.18),
          blurRadius: blur,
          offset: Offset(0, y),
        ),
      ];

  /// Gradien tonal tipis (primary → primary container), bukan gradient warna.
  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primary, scheme.primary],
      );

  /// Permukaan kaca: datar, M3 memakai tonal bukan gradien.
  static LinearGradient get glassSheen => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scheme.surfaceContainerHigh.withValues(alpha: 0.0),
          scheme.surfaceContainerHigh.withValues(alpha: 0.0),
        ],
      );

  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [heroTop, heroTop],
      );
}

/// Radius khas M3 Expressive (kartu besar, sudut membulat penuh).
class AppRadii {
  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double pill = 999;
}

class AppSpace {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 30;
}

class AppMotion {
  static const Duration fast = Motion.fast;
  static const Duration base = Motion.base;
  static const Duration slow = Motion.slow;
}

ThemeData buildTheme([AppAppearance? appearance]) {
  if (appearance != null) {
    // Pertahankan seed yang sedang aktif (mis. warna sistem); jangan reset ke
    // default setiap rebuild.
    AppColors.apply(seedColor: AppColors.seed, appearance: appearance);
  }
  final scheme = AppColors.scheme;
  final dark = AppColors.isDark;

  final base = ThemeData(
    useMaterial3: true,
    // Font aplikasi: Linotte (assets/fonts). Semua teks memakai keluarga ini
    // lewat textTheme di bawah; widget yang memaksa font lain tetap menang.
    fontFamily: 'Linotte',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: MotionPageTransitionsBuilder(),
        TargetPlatform.iOS: MotionPageTransitionsBuilder(),
        TargetPlatform.linux: MotionPageTransitionsBuilder(),
        TargetPlatform.macOS: MotionPageTransitionsBuilder(),
        TargetPlatform.windows: MotionPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
  );

  final text = base.textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineLarge: text.headlineLarge?.copyWith(
        fontSize: 30,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15.5, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: text.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: text.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor:
            scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        shape: const StadiumBorder(),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(
          scheme.onPrimary.withValues(alpha: 0.12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : scheme.outline,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 10,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      showValueIndicator: ShowValueIndicator.never,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondaryContainer
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
        side: WidgetStateProperty.all(
          BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        shape: WidgetStateProperty.all(const StadiumBorder()),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 14),
      actionTextColor: scheme.inversePrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 15,
        height: 1.45,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearMinHeight: 8,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
