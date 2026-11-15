/// Aturan kecil untuk mengenali tautan unduhan Pixeldrain yang dipakai
/// halaman webnya (termasuk saat verifikasi captcha).
class WebDownloadLinks {
  WebDownloadLinks._();

  /// true untuk tautan berkas Pixeldrain: `/api/file/<id>` atau
  /// `?download`, di domain pixeldrain.com maupun mirror.
  static bool isPixeldrainDownloadUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;

    final host = uri.host.toLowerCase();
    final isPixeldrain = host == 'pixeldrain.com' ||
        host.endsWith('.pixeldrain.com') ||
        host.contains('pixeldrain');
    if (!isPixeldrain) return false;

    final path = uri.path.toLowerCase();
    if (path.contains('/api/file/')) return true;
    if (path.contains('/api/filesystem/')) return true;
    return uri.queryParameters.containsKey('download');
  }
}
