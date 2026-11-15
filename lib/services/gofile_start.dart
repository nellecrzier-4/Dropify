import 'package:shared_preferences/shared_preferences.dart';

/// Halaman awal WebView Gofile per akun — "folder utama" pengguna.
///
/// Disimpan di SharedPreferences dengan kunci per token akun, supaya tautan
/// folder tidak perlu diketik ulang setiap kali membuka Gofile.
class GofileStart {
  GofileStart._();

  static const String _prefix = 'gofile_start_';

  static String _key(String? token) {
    final value = (token ?? '').trim();
    return '$_prefix${value.isEmpty ? 'guest' : value}';
  }

  /// URL folder utama yang tersimpan, atau null.
  static Future<String?> load(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_key(token));
    return (url == null || url.trim().isEmpty) ? null : url;
  }

  static Future<void> save(String? token, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(token), url.trim());
  }

  static Future<void> clear(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(token));
  }

  /// true kalau [raw] adalah halaman folder/berbagi Gofile yang berguna
  /// dijadikan halaman awal — bukan halaman login, bukan tautan berkas, dan
  /// bukan beranda kosong.
  static bool isFolderPage(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    if (host != 'gofile.io' && host != 'www.gofile.io') return false;

    final path = uri.path.toLowerCase();
    if (path.startsWith('/login')) return false;
    if (path.startsWith('/download')) return false;

    final segments = uri.pathSegments;
    final hasId = segments.length >= 2 && segments[1].trim().isNotEmpty;
    if (path.startsWith('/d/') ||
        path.startsWith('/folder/') ||
        path.startsWith('/contents/')) {
      return hasId;
    }
    final shareId = uri.queryParameters['c']?.trim() ?? '';
    return shareId.isNotEmpty;
  }

  /// Bentuk pendek yang enak ditaruh di kolom teks: https://gofile.io/d/<id>
  static String shortLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return raw;
    final path = uri.path;
    if (path.toLowerCase().startsWith('/d/') && uri.pathSegments.length >= 2) {
      return 'https://gofile.io/d/${uri.pathSegments[1]}';
    }
    return raw.trim();
  }

  /// URL yang bisa dipakai langsung sebagai halaman awal dari isian pengguna.
  /// Menerima id pendek (`2TK55X6D`) maupun tautan penuh.
  static String? normaliseInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return isFolderPage(text) ? text : null;
    }
    if (RegExp(r'^[A-Za-z0-9]{6,64}$').hasMatch(text)) {
      return 'https://gofile.io/d/$text';
    }
    return null;
  }
}
