import 'package:dropify/services/download_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('id berkas diambil dari URL API dan halaman', () {
    expect(fileIdFromUrl('https://pixeldrain.com/api/file/AbC123?download'), 'AbC123');
    expect(fileIdFromUrl('https://pixeldrain.com/u/AbC123'), 'AbC123');
    expect(fileIdFromUrl('https://cdn.pixeldrain.eu.cc/AbC123?download'), isNull);
    expect(
      fileIdFromUrl('https://pixeldrain.com/api/filesystem/me/Docs/a.zip'),
      isNull,
      reason: 'path filesystem bukan id tunggal',
    );
  });
}
