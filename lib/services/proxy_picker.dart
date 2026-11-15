import 'dart:convert';
import 'dart:io';

/// Mengambil kandidat proxy publik dari tiga negara (SG/ID/JP) tanpa mengujinya.
///
/// Dipakai layar pemilih: kalau pengujian otomatis gagal (jaringan pengguna
/// memblokir, atau proxy terlalu lambat), pengguna tetap bisa memilih sendiri.
class ProxyCatalog {
  ProxyCatalog._();

  static const List<String> countries = ['SG', 'ID', 'JP'];

  static const String _feed =
      'https://api.proxyscrape.com/v4/free-proxy-list/get'
      '?request=display_proxies&country={cc}&protocol=http'
      '&proxy_format=ipport&format=text';

  /// Maksimal [limit] alamat, dibagi dari tiga negara di atas.
  static Future<List<String>> fetch({int limit = 24}) async {
    final perCountry = (limit / countries.length).ceil() + 4;
    final out = <String>[];
    for (final cc in countries) {
      final list = await _one(cc);
      for (final item in list.take(perCountry)) {
        if (!out.contains(item)) out.add(item);
        if (out.length >= limit) break;
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<List<String>> _one(String cc) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_feed.replaceAll('{cc}', cc)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return const [];
      }
      final body = await res.transform(const SystemEncoding().decoder).join();
      return [
        for (final line in body.split('\n'))
          if (_valid(line.trim())) line.trim(),
      ];
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  static bool _valid(String value) {
    if (value.isEmpty || value.contains('://')) return false;
    final parts = value.split(':');
    if (parts.length != 2) return false;
    final port = int.tryParse(parts[1]);
    return parts[0].isNotEmpty && port != null && port > 0 && port < 65536;
  }
}
