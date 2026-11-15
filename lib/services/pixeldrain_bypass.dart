import 'package:shared_preferences/shared_preferences.dart';

/// Pembuat link download Pixeldrain lewat mirror bypass.
///
/// Aplikasi tidak memakai direct link Pixeldrain untuk mengunduh. Setiap kali
/// user menekan sebuah file, [PixeldrainBypass] membuat link baru di mirror
/// bypass (default: cdn.pixeldrain.eu.cc, mirror yang dipakai
/// pixeldrain-bypass.gamedrive.org). Mirror tersebut meneruskan file dari
/// Pixeldrain tanpa batas kecepatan / kuota harian.
///
/// Format link:
///   file  : https://<mirror>/<fileId>?download
///   album : https://<mirror>/zip/<albumId>
///   folder: https://<mirror>/dzip/<folderId>
class PixeldrainBypass {
  PixeldrainBypass._();

  static const String _prefEnabled = 'bypass_enabled';
  static const String _prefMirror = 'bypass_mirror';

  /// Muat pilihan pengguna (sakelar di Settings).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefEnabled) ?? _enabled;
      final saved = prefs.getString(_prefMirror);
      if (saved != null && saved.trim().isNotEmpty) {
        _mirror = saved.trim();
      }
    } catch (_) {}
  }

  /// Nyalakan/matikan mirror bypass; disimpan supaya bertahan setelah restart.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, value);
    } catch (_) {}
  }

  /// Mirror default. Ganti di sini kalau domainnya berubah.
  static const String defaultMirror = 'cdn.pixeldrain.eu.cc';

  /// Halaman publik layanan bypass (dipakai untuk tombol "Buka di browser").
  static const String serviceUrl = 'https://pixeldrain-bypass.gamedrive.org/';

  static String _mirror = defaultMirror;
  static bool _enabled = true;

  static String get mirror => _mirror;

  /// Kalau false, aplikasi memakai link Pixeldrain biasa.
  static bool get enabled => _enabled;

  static void configure({String? mirror, bool? enabled}) {
    if (mirror != null && mirror.trim().isNotEmpty) {
      _mirror = mirror.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll('/', '');
    }
    if (enabled != null) _enabled = enabled;
  }

  /// Link download bypass untuk satu file. Null kalau bypass dimatikan atau
  /// file tidak punya id (mis. file filesystem yang belum punya id).
  static String? linkForFileId(String? fileId, {bool download = true}) {
    if (!_enabled) return null;
    final id = fileId?.trim() ?? '';
    if (id.isEmpty) return null;
    final suffix = download ? '?download' : '';
    return 'https://$_mirror/${Uri.encodeComponent(id)}$suffix';
  }

  static String albumZipUrl(String albumId) => 'https://$_mirror/zip/$albumId';

  static String folderZipUrl(String folderId) => 'https://$_mirror/dzip/$folderId';

  /// Link bypass kalau memungkinkan, kalau tidak link Pixeldrain biasa.
  static String resolveFileUrl({String? fileId, required String fallbackUrl}) {
    final bypass = linkForFileId(fileId);
    if (bypass != null) return bypass;
    return fallbackUrl;
  }
}
