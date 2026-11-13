import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Preferensi tampilan: aksen ikut warna sistem dan mode AMOLED.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const MethodChannel _channel = MethodChannel('com.nel.dropify/native');

  static const _prefDynamic = 'theme_dynamic';
  static const _prefAmoled = 'theme_amoled';

  bool _dynamic = true;
  bool _amoled = false;
  Color? _systemAccent;
  bool _systemAccentAvailable = false;

  bool get dynamicColor => _dynamic;
  bool get amoled => _amoled;
  bool get systemAccentAvailable => _systemAccentAvailable;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _dynamic = prefs.getBool(_prefDynamic) ?? true;
    _amoled = prefs.getBool(_prefAmoled) ?? false;
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

  Future<void> setAmoled(bool value) async {
    _amoled = value;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAmoled, value);
  }

  void _apply() {
    AppColors.apply(
      seedColor: _dynamic ? _systemAccent : null,
      amoled: _amoled,
    );
  }
}
