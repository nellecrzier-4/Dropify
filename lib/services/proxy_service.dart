import 'dart:async';
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
  static const String _keyAuto = 'proxy_auto';

  /// Negara sumber proxy otomatis: Singapura, Indonesia, Jepang.
  static const List<String> autoCountries = ['SG', 'ID', 'JP'];

  static const String _autoFeed =
      'https://api.proxyscrape.com/v4/free-proxy-list/get'
      '?request=display_proxies&country={cc}&protocol=http'
      '&proxy_format=ipport&format=text';

  bool _enabled = false;
  bool _auto = false;
  List<String> _proxies = const [];
  List<String> _autoPool = const [];
  int _index = 0;
  int _autoIndex = 0;
  bool _refreshing = false;

  bool get enabled => _enabled;

  bool get auto => _auto;

  /// Proxy manual yang diisi pengguna.
  List<String> get proxies => _proxies;

  /// Proxy hasil uji otomatis (SG/ID/JP).
  List<String> get autoPool => _autoPool;

  bool get refreshing => _refreshing;

  /// Daftar yang sedang dipakai (manual atau otomatis).
  List<String> get activeProxies => _proxies.isNotEmpty ? _proxies : _autoPool;

  /// Proxy yang sedang dipakai, mis. `host:port` — null kalau tidak aktif.
  String? get current {
    if (!_enabled) return null;
    if (_proxies.isNotEmpty) return _proxies[_index % _proxies.length];
    if (_auto && _autoPool.isNotEmpty) {
      return _autoPool[_autoIndex % _autoPool.length];
    }
    return null;
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
    _auto = prefs.getBool(_keyAuto) ?? false;
    _proxies = prefs.getStringList(_keyList) ?? const [];
    _index = prefs.getInt(_keyIndex) ?? 0;
    if (_index >= _proxies.length) _index = 0;
    notifyListeners();
  }

  Future<void> setAuto(bool value) async {
    _auto = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAuto, value);
    if (value && _autoPool.isEmpty) await refreshAuto();
  }

  /// Ambil daftar proxy publik SG/ID/JP lalu uji satu per satu.
  ///
  /// Hanya proxy yang benar-benar bisa meneruskan permintaan HTTPS yang
  /// disimpan. Hasilnya di memori saja — tidak ditulis ke penyimpanan.
  Future<int> refreshAuto() async {
    if (_refreshing) return _autoPool.length;
    _refreshing = true;
    notifyListeners();
    try {
      final candidates = <String>[];
      for (final cc in autoCountries) {
        final list = await _fetchCountry(cc);
        for (final item in list) {
          if (!candidates.contains(item)) candidates.add(item);
        }
      }
      final verified = <String>[];
      // Uji bertahap: cukup 4 proxy hidup untuk berputar.
      const batch = 12;
      for (var i = 0; i < candidates.length && verified.length < 4; i += batch) {
        final slice = candidates.skip(i).take(batch).toList();
        final results = await Future.wait(slice.map(_isAlive));
        for (var j = 0; j < slice.length; j++) {
          if (results[j] && !verified.contains(slice[j])) verified.add(slice[j]);
        }
      }
      _autoPool = verified;
      _autoIndex = 0;
      return verified.length;
    } catch (_) {
      return _autoPool.length;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<List<String>> _fetchCountry(String cc) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_autoFeed.replaceAll('{cc}', cc)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return const [];
      }
      final body = await res.transform(const SystemEncoding().decoder).join();
      return [
        for (final line in body.split('\n'))
          if (isValid(line.trim()) && !line.trim().contains('://')) line.trim(),
      ];
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  /// Cek apakah proxy bisa meneruskan HTTPS.
  Future<bool> _isAlive(String proxy) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    client.findProxy = (_) => 'PROXY $proxy';
    try {
      final req = await client.getUrl(Uri.parse('https://example.com/'));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
      return res.statusCode > 0;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
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
    if (_proxies.isEmpty && _enabled && !_auto) await setEnabled(false);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value && _proxies.isNotEmpty;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, _enabled);
  }

  /// Pindah ke proxy berikutnya; true kalau ada proxy lain yang dicoba.
  bool rotate() {
    if (!_enabled) return false;
    if (_proxies.isEmpty) {
      if (_autoPool.length < 2) return false;
      _autoIndex = (_autoIndex + 1) % _autoPool.length;
      notifyListeners();
      return true;
    }
    if (_proxies.length < 2) return false;
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
