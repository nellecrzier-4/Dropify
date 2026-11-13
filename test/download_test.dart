import 'package:dropify/services/pixeldrain_bypass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membuat link bypass baru untuk setiap file', () {
    expect(
      PixeldrainBypass.linkForFileId('QJ9MzyPM'),
      'https://cdn.pixeldrain.eu.cc/QJ9MzyPM?download',
    );
    expect(PixeldrainBypass.linkForFileId(null), isNull);
    expect(PixeldrainBypass.linkForFileId('   '), isNull);
  });

  test('album dan folder memakai endpoint zip', () {
    expect(PixeldrainBypass.albumZipUrl('abc'), 'https://cdn.pixeldrain.eu.cc/zip/abc');
    expect(PixeldrainBypass.folderZipUrl('dir'), 'https://cdn.pixeldrain.eu.cc/dzip/dir');
  });

  test('mirror bisa dikonfigurasi', () {
    PixeldrainBypass.configure(mirror: 'https://mirror.example.com/');
    expect(
      PixeldrainBypass.linkForFileId('xyz'),
      'https://mirror.example.com/xyz?download',
    );
    PixeldrainBypass.configure(mirror: PixeldrainBypass.defaultMirror);
  });
}
