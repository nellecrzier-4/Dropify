import 'package:shared_preferences/shared_preferences.dart';

/// Sesi Pixeldrain hasil verifikasi captcha di WebView.
///
/// Captcha diselesaikan pengguna sendiri di halaman resmi Pixeldrain; aplikasi
/// hanya menyimpan cookie sesi yang dihasilkan lalu memakainya untuk unduhan.
/// Tidak ada captcha yang dipecahkan otomatis.
class PdSession {
  PdSession._();

  static final PdSession instance = PdSession._();

  static const String _key = 'pd_session_cookie';

  String? _cookie;

  /// Header Cookie siap pakai, mis. `PHPSESSID=...; pd_session=...`.
  String? get cookie => _cookie;

  bool get hasSession => (_cookie?.isNotEmpty ?? false);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      if (value != null && value.isNotEmpty) _cookie = value;
    } catch (_) {}
  }

  Future<void> save(String cookie) async {
    final clean = cookie.trim();
    _cookie = clean.isEmpty ? null : clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cookie == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, _cookie!);
      }
    } catch (_) {}
  }

  Future<void> clear() => save('');
}
