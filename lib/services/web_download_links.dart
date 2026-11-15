/// Aturan kecil untuk unduhan yang dimulai dari WebView Gofile.
///
/// WebView Android melaporkan awal unduhan lewat `DownloadListener`, dan
/// webview_flutter_android meneruskannya sebagai `onNavigationRequest`
/// (`isForMainFrame: true`) berisi URL berkasnya. Supaya halaman situs tidak
/// ikut dianggap berkas, pencocokan URL dibuat ketat di sini dan bisa diuji
/// tanpa WebView.
class WebDownloadLinks {
  WebDownloadLinks._();

  /// Nama berkas cadangan kalau URL tidak menyebutkannya.
  static const String fallbackName = 'gofile-download';

  /// true kalau [raw] adalah URL berkas Gofile yang harus diunduh aplikasi,
  /// bukan halaman yang harus dimuat WebView.
  static bool isGofileDownloadUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Domain utama: hanya jalur unduhan langsung. Halaman biasa
    // (gofile.io/d/xxx, folder, akun) tetap dimuat di WebView.
    if (host == 'gofile.io' || host == 'www.gofile.io') {
      if (path.startsWith('/download/direct/')) return true;
      if (path.startsWith('/download/web/')) return true;
      if (uri.queryParameters.containsKey('download')) return true;
      return path.startsWith('/download/') && _hasFileExtension(uri.path);
    }

    // Node penyimpanan (mis. store-eu-par-1.gofile.io) selalu menyajikan
    // berkas, bukan halaman.
    if (host.endsWith('.gofile.io')) {
      return path.contains('/download/') || _hasFileExtension(uri.path);
    }

    return false;
  }

  /// true kalau [raw] bisa diunduh DownloadService (http/https saja).
  static bool isDownloadable(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'https' || scheme == 'http';
  }

  /// Nama berkas dari URL; [preferred] (mis. atribut `download` pada tautan)
  /// dipakai lebih dulu kalau berisi nama yang masuk akal.
  static String fileNameFromUrl(String raw, {String? preferred}) {
    final wanted = (preferred ?? '').trim();
    if (wanted.isNotEmpty) return wanted;

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        final decoded = Uri.decodeComponent(last);
        if (_hasFileExtension(decoded) || decoded.length > 2) return decoded;
      }
    }
    return fallbackName;
  }

  static bool _hasFileExtension(String path) {
    final segment = path.split('/').last;
    final dot = segment.lastIndexOf('.');
    if (dot <= 0 || dot == segment.length - 1) return false;
    final ext = segment.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext);
  }
}
