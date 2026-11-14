import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Preferensi tampilan: Terang / Gelap / AMOLED dan aksen ikut warna sistem.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const MethodChannel _channel = MethodChannel('com.nel.dropify/native');

  static const _prefDynamic = 'theme_dynamic';
  static const _prefAppearance = 'theme_appearance';
  static const _prefAmoled = 'theme_amoled';

  bool _dynamic = true;
  AppAppearance _appearance = AppAppearance.light;
  Color? _systemAccent;
  bool _systemAccentAvailable = false;

  bool get dynamicColor => _dynamic;
  AppAppearance get appearance => _appearance;
  bool get isDark => _appearance != AppAppearance.light;
  bool get amoled => _appearance == AppAppearance.amoled;
  bool get systemAccentAvailable => _systemAccentAvailable;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _dynamic = prefs.getBool(_prefDynamic) ?? true;
    // Migrasi dari versi lama yang hanya punya sakelar AMOLED.
    final legacyAmoled = prefs.getBool(_prefAmoled) ?? false;
    final stored = prefs.getString(_prefAppearance);
    _appearance = AppAppearance.values.firstWhere(
      (a) => a.name == stored,
      orElse: () => legacyAmoled ? AppAppearance.amoled : AppAppearance.light,
    );
    await _readSystemAccent();
    _apply();
  }

  Future<void> _readSystemAccent() async {
    try {
      final value = await _channel.invokeMethod<int>('systemAccent');
      if (value != null && value != 0) {
        _systemAccent = Color(value);
        _systemAccentAvailable = true;
      }
    } on PlatformException {
      _systemAccentAvailable = false;
    } on MissingPluginException {
      _systemAccentAvailable = false;
    }
  }

  Future<void> setDynamic(bool value) async {
    _dynamic = value;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDynamic, value);
  }

  Future<void> setAppearance(AppAppearance value) async {
    if (_appearance == value) return;
    _appearance = value;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAppearance, value.name);
    // Status bar & navigation bar ikut terang/gelap.
    SystemChrome.setSystemUIOverlayStyle(systemOverlayStyle);
  }

  /// Kompatibilitas: sakelar lama hanya menyalakan/mematikan AMOLED.
  Future<void> setAmoled(bool value) => setAppearance(
        value
            ? AppAppearance.amoled
            : (_appearance == AppAppearance.amoled
                ? AppAppearance.dark
                : _appearance),
      );

  /// Gaya status bar sesuai tampilan aktif.
  SystemUiOverlayStyle get systemOverlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      );

  void _apply() {
    AppColors.apply(
      seedColor: _dynamic ? _systemAccent : null,
      appearance: _appearance,
    );
  }
}
