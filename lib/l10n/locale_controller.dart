import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Pilihan bahasa: ikuti sistem, atau English.
class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const String _prefKey = 'app_language';

  AppLanguage _mode = AppLanguage.system;
  Locale _deviceLocale = const Locale('en');
  bool _loaded = false;

  AppLanguage get mode => _mode;
  bool get loaded => _loaded;

  Locale get locale {
    if (_mode == AppLanguage.english) return const Locale('en');
    return _deviceLocale.languageCode == 'id'
        ? const Locale('id')
        : const Locale('en');
  }

  AppStrings get strings =>
      locale.languageCode == 'id' ? const StringsId() : const StringsEn();

  /// Bahasa perangkat, terlepas dari pilihan pengguna — dipakai sebagai
  /// keterangan di opsi "Ikuti sistem".
  AppStrings get deviceStrings =>
      _deviceLocale.languageCode == 'id' ? const StringsId() : const StringsEn();

  String get deviceLanguageName => deviceStrings.languageName;

  Future<void> load() async {
    _deviceLocale = PlatformDispatcher.instance.locale;
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_prefKey) == 'en'
        ? AppLanguage.english
        : AppLanguage.system;
    _loaded = true;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  Future<void> setMode(AppLanguage mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      mode == AppLanguage.english ? 'en' : 'system',
    );
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final next = locales?.isNotEmpty == true
        ? locales!.first
        : PlatformDispatcher.instance.locale;
    if (next.languageCode == _deviceLocale.languageCode) return;
    _deviceLocale = next;
    if (_mode == AppLanguage.system) notifyListeners();
  }
}

/// Menyediakan [AppStrings] ke seluruh widget tree.
class LocaleScope extends InheritedWidget {
  const LocaleScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.strings ?? LocaleController.instance.strings;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) =>
      oldWidget.strings != strings;
}

extension StringsContext on BuildContext {
  AppStrings get s => LocaleScope.of(this);
}
