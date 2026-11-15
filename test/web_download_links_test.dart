import 'package:dropify/services/web_download_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGofileDownloadUrl', () {
    test('node penyimpanan = berkas', () {
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://store-eu-par-1.gofile.io/download/web/tok/berkas.zip',
        ),
        isTrue,
      );
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://store1.gofile.io/download/abc123/foto.jpg',
        ),
        isTrue,
      );
    });

    test('jalur unduhan langsung di domain utama', () {
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://gofile.io/download/direct/abc123',
        ),
        isTrue,
      );
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://gofile.io/download/web/abc123/film.mkv',
        ),
        isTrue,
      );
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://gofile.io/dl?id=abc&download=1',
        ),
        isTrue,
      );
    });

    test('halaman biasa tetap dimuat WebView', () {
      for (final url in [
        'https://gofile.io/',
        'https://gofile.io/d/abc123',
        'https://gofile.io/login/token',
        'https://gofile.io/download/direct',
        'https://www.gofile.io/contents/abc123',
      ]) {
        expect(WebDownloadLinks.isGofileDownloadUrl(url), isFalse,
            reason: url);
      }
    });

    test('situs lain tidak pernah diambil alih', () {
      expect(
        WebDownloadLinks.isGofileDownloadUrl(
          'https://pixeldrain.com/api/file/abc?download',
        ),
        isFalse,
      );
      expect(
        WebDownloadLinks.isGofileDownloadUrl('https://example.com/download/x.zip'),
        isFalse,
      );
      expect(WebDownloadLinks.isGofileDownloadUrl('blob:https://gofile.io/x'),
          isFalse);
      expect(WebDownloadLinks.isGofileDownloadUrl('javascript:void(0)'), isFalse);
      expect(WebDownloadLinks.isGofileDownloadUrl('tidak-valid'), isFalse);
    });
  });

  group('fileNameFromUrl', () {
    test('ambil segmen terakhir URL', () {
      expect(
        WebDownloadLinks.fileNameFromUrl(
          'https://store-eu-par-1.gofile.io/download/web/tok/berkas%20saya.zip',
        ),
        'berkas saya.zip',
      );
      expect(
        WebDownloadLinks.fileNameFromUrl(
          'https://gofile.io/download/direct/abc/foto.jpg?token=1',
        ),
        'foto.jpg',
      );
    });

    test('nama dari atribut download dipakai lebih dulu', () {
      expect(
        WebDownloadLinks.fileNameFromUrl(
          'https://store-eu-par-1.gofile.io/download/web/tok/hash',
          preferred: 'Laporan Akhir.pdf',
        ),
        'Laporan Akhir.pdf',
      );
    });

    test('URL tanpa nama berkas -> nama cadangan', () {
      expect(
        WebDownloadLinks.fileNameFromUrl('https://gofile.io/download/direct/'),
        WebDownloadLinks.fallbackName,
      );
      expect(
        WebDownloadLinks.fileNameFromUrl('https://store1.gofile.io/download/a/b/'),
        WebDownloadLinks.fallbackName,
      );
    });
  });

  group('isDownloadable', () {
    test('hanya http/https', () {
      expect(WebDownloadLinks.isDownloadable('https://gofile.io/a'), isTrue);
      expect(WebDownloadLinks.isDownloadable('http://gofile.io/a'), isTrue);
      expect(WebDownloadLinks.isDownloadable('blob:https://a/b'), isFalse);
      expect(WebDownloadLinks.isDownloadable('data:text/plain,hi'), isFalse);
      expect(WebDownloadLinks.isDownloadable('about:blank'), isFalse);
    });
  });
}
