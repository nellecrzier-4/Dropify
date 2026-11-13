import 'package:dropify/services/pd_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('link file', () {
    final link = PdLink.parse('https://pixeldrain.com/u/QJ9MzyPM');
    expect(link, isNotNull);
    expect(link!.type, PdLinkType.file);
    expect(link.id, 'QJ9MzyPM');
  });

  test('link api dengan query', () {
    final link = PdLink.parse(
      'https://pixeldrain.com/api/file/QJ9MzyPM?download',
    );
    expect(link!.type, PdLinkType.file);
    expect(link.id, 'QJ9MzyPM');
  });

  test('album dan folder', () {
    expect(PdLink.parse('https://pixeldrain.com/l/abc12345')!.type,
        PdLinkType.album);
    expect(PdLink.parse('https://pixeldra.in/d/dir12345')!.type,
        PdLinkType.folder);
  });

  test('id polos', () {
    final link = PdLink.parse('QJ9MzyPM');
    expect(link!.type, PdLinkType.file);
    expect(link.id, 'QJ9MzyPM');
  });

  test('link tidak dikenal', () {
    expect(PdLink.parse('https://example.com/u/abc'), isNull);
    expect(PdLink.parse(''), isNull);
  });

  test('link bypass dibuat dari mirror', () {
    final link = PdLink.parse('https://pixeldrain.com/u/QJ9MzyPM')!;
    expect(link.bypassUrl, contains('cdn.pixeldrain.eu.cc'));
    expect(link.bypassUrl, contains('QJ9MzyPM'));
  });
}
