import 'package:dropify/services/gofile_start.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('isFolderPage', () {
    test('folder dan berbagi dianggap halaman folder', () {
      for (final url in [
        'https://gofile.io/d/2TK55X6D',
        'https://gofile.io/folder/2TK55X6D',
        'https://gofile.io/contents/2TK55X6D',
        'https://gofile.io/?c=2TK55X6D',
      ]) {
        expect(GofileStart.isFolderPage(url), isTrue, reason: url);
      }
    });

    test('login, beranda, dan tautan berkas ditolak', () {
      for (final url in [
        'https://gofile.io/',
        'https://gofile.io/login/abc',
        'https://gofile.io/d/',
        'https://gofile.io/download/direct/abc',
        'https://store-eu-par-1.gofile.io/download/web/a/b.zip',
        'https://example.com/d/abc',
        'bukan-url',
      ]) {
        expect(GofileStart.isFolderPage(url), isFalse, reason: url);
      }
    });
  });

  group('normaliseInput', () {
    test('id pendek jadi tautan folder', () {
      expect(
        GofileStart.normaliseInput('2TK55X6D'),
        'https://gofile.io/d/2TK55X6D',
      );
    });

    test('tautan penuh diterima, yang bukan folder ditolak', () {
      expect(
        GofileStart.normaliseInput('https://gofile.io/d/2TK55X6D'),
        'https://gofile.io/d/2TK55X6D',
      );
      expect(GofileStart.normaliseInput('https://gofile.io/'), isNull);
      expect(GofileStart.normaliseInput('   '), isNull);
      expect(GofileStart.normaliseInput('go file!'), isNull);
    });
  });

  test('shortLink merapikan tautan panjang', () {
    expect(
      GofileStart.shortLink('https://gofile.io/d/2TK55X6D?web=1'),
      'https://gofile.io/d/2TK55X6D',
    );
  });

  test('simpan, muat, dan hapus per akun', () async {
    expect(await GofileStart.load('tokenA'), isNull);

    await GofileStart.save('tokenA', 'https://gofile.io/d/AAA111');
    await GofileStart.save('tokenB', 'https://gofile.io/d/BBB222');

    expect(await GofileStart.load('tokenA'), 'https://gofile.io/d/AAA111');
    expect(await GofileStart.load('tokenB'), 'https://gofile.io/d/BBB222');
    expect(await GofileStart.load(null), isNull);

    await GofileStart.clear('tokenA');
    expect(await GofileStart.load('tokenA'), isNull);
    expect(await GofileStart.load('tokenB'), 'https://gofile.io/d/BBB222');
  });
}
