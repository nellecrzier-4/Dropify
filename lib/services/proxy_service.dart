import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daftar proxy milik pengguna untuk unduhan (opsional).
///
/// Berguna kalau jaringan pengguna memblokir, atau saat Pixeldrain membalas
/// 429/403 karena batas harian: aplikasi memutar ke proxy berikutnya lalu
/// mencoba lagi. 404 tidak pernah memicu putaran — 404 berarti berkasnya tidak
/// ada, bukan soal jaringan.
class ProxyService extends ChangeNotifier {
  ProxyService._();

  static final ProxyService instance = ProxyService._();

  static const String _keyEnabled = 'proxy_enabled';
  static const String _keyList = 'proxy_list';
  static const String _keyIndex = 'proxy_index';

  bool _enabled = false;
  List<String> _proxies = const [];
  int _index = 0;

  bool get enabled => _enabled;

  List<String> get proxies => _proxies;

  /// Proxy yang sedang dipakai, mis. `host:port` — null kalau tidak aktif.
  String? get current {
    if (!_enabled || _proxies.isEmpty) return null;
    return _proxies[_index % _proxies.length];
  }

  /// Nilai untuk `HttpClient.findProxy`.
  String get findProxyValue {
    final value = current;
    if (value == null) return 'DIRECT';
    final host = value.replaceFirst(RegExp(r'^[a-z]+://'), '');
    return 'PROXY $host';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _proxies = prefs.getStringList(_keyList) ?? const [];
    _index = prefs.getInt(_keyIndex) ?? 0;
    if (_index >= _proxies.length) _index = 0;
    notifyListeners();
  }

  /// Simpan daftar proxy (satu per baris; `host:port` atau `scheme://host:port`).
  Future<void> setList(String text) async {
    final parts = text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && isValid(e))
        .toList();
    _proxies = parts;
    if (_index >= _proxies.length) _index = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyList, _proxies);
    await prefs.setInt(_keyIndex, _index);
    if (_proxies.isEmpty && _enabled) await setEnabled(false);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value && _proxies.isNotEmpty;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, _enabled);
  }

  /// Pindah ke proxy berikutnya; true kalau ada proxy lain yang dicoba.
  bool rotate() {
    if (!_enabled || _proxies.length < 2) return false;
    _index = (_index + 1) % _proxies.length;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_keyIndex, _index),
    );
    return true;
  }

  static bool isValid(String value) {
    final text = value.replaceFirst(RegExp(r'^[a-z]+://'), '').trim();
    if (text.isEmpty) return false;
    final parts = text.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    return parts[0].isNotEmpty && port != null && port > 0 && port < 65536;
  }

  /// Bangun HttpClient yang mengikuti proxy aktif (dipakai adapter Dio).
  HttpClient createHttpClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 30);
    client.findProxy = (_) => findProxyValue;
    return client;
  }
}
