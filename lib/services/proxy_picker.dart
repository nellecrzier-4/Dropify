import 'dart:io';

/// Mengambil kandidat proxy publik dari tiga negara (SG/ID/JP) tanpa mengujinya.
///
/// Dipakai layar pemilih: kalau pengujian otomatis gagal (jaringan pengguna
/// memblokir, atau proxy terlalu lambat), pengguna tetap bisa memilih sendiri.
class ProxyCatalog {
  ProxyCatalog._();

  /// Urutan negara menurut kedekatan ke pengguna Indonesia.
  static const List<String> countries = ['ID', 'SG', 'JP'];

  static const Map<String, String> countryNames = {
    'ID': 'Indonesia',
    'SG': 'Singapura',
    'JP': 'Jepang',
  };

  /// Sumber: proxifly/free-proxy-list — daftar per negara, teks polos.
  static const String _feed =
      'https://raw.githubusercontent.com/proxifly/free-proxy-list/main/'
      'proxies/countries/{cc}/data.txt';

  /// Maksimal [limit] alamat, dibagi dari tiga negara di atas.
  static Future<List<ProxyCandidate>> fetch({int limit = 24}) async {
    final perCountry = (limit / countries.length).ceil() + 2;
    final out = <ProxyCandidate>[];
    for (final cc in countries) {
      final list = await _one(cc);
      for (final item in list.take(perCountry)) {
        if (out.any((p) => p.address == item)) continue;
        out.add(ProxyCandidate(address: item, country: cc));
        if (out.length >= limit) break;
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Ukur latensi (ms) satu proxy lewat generate_204; null kalau gagal.
  static Future<int?> latency(String proxy, {int timeoutSeconds = 4}) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSeconds)
      ..idleTimeout = Duration(seconds: timeoutSeconds);
    client.findProxy = (_) => 'PROXY $proxy';
    final watch = Stopwatch()..start();
    try {
      final req = await client.getUrl(
        Uri.parse('https://www.gstatic.com/generate_204'),
      );
      final res = await req.close().timeout(Duration(seconds: timeoutSeconds));
      await res.drain<void>();
      watch.stop();
      if (res.statusCode != 204 && res.statusCode != 200) return null;
      return watch.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
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
      final out = <String>[];
      for (final raw in body.split('\n')) {
        final line = raw.trim();
        // Ambil hanya proxy HTTP/HTTPS; SOCKS tidak didukung findProxy Dart.
        if (line.startsWith('socks')) continue;
        final plain = line.replaceFirst(RegExp(r'^https?://'), '');
        if (_valid(plain) && !out.contains(plain)) out.add(plain);
      }
      return out;
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


/// Satu alamat proxy beserta negaranya dan hasil ukur latensi.
class ProxyCandidate {
  ProxyCandidate({required this.address, required this.country});

  final String address;
  final String country;

  /// Latensi dalam milidetik; null = belum diukur, -1 = gagal.
  int? latencyMs;

  String get countryName => ProxyCatalog.countryNames[country] ?? country;

  String get latencyLabel {
    final ms = latencyMs;
    if (ms == null) return 'mengukur…';
    if (ms < 0) return 'gagal';
    return '$ms ms';
  }
}
