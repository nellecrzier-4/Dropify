import 'package:dropify/services/proxy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProxyService.instance.setList('');
    await ProxyService.instance.setEnabled(false);
  });

  test('format proxy divalidasi', () {
    expect(ProxyService.isValid('127.0.0.1:8080'), isTrue);
    expect(ProxyService.isValid('proxy.local:3128'), isTrue);
    expect(ProxyService.isValid('http://10.0.0.2:8080'), isTrue);
    expect(ProxyService.isValid('127.0.0.1'), isFalse);
    expect(ProxyService.isValid('127.0.0.1:99999'), isFalse);
    expect(ProxyService.isValid(':8080'), isFalse);
  });

  test('daftar disimpan tanpa entri rusak dan baris kosong', () async {
    await ProxyService.instance.setList(' 1.1.1.1:80 \n\n contoh:3128,rusak');
    expect(ProxyService.instance.proxies, ['1.1.1.1:80', 'contoh:3128']);
  });

  test('putar hanya saat aktif dan ada lebih dari satu proxy', () async {
    await ProxyService.instance.setList('1.1.1.1:80');
    await ProxyService.instance.setEnabled(true);
    expect(ProxyService.instance.rotate(), isFalse, reason: 'butuh dua proxy');
    expect(ProxyService.instance.current, '1.1.1.1:80');

    await ProxyService.instance.setList('1.1.1.1:80\n2.2.2.2:80');
    await ProxyService.instance.setEnabled(true);
    expect(ProxyService.instance.current, '1.1.1.1:80');
    expect(ProxyService.instance.rotate(), isTrue);
    expect(ProxyService.instance.current, '2.2.2.2:80');
    expect(ProxyService.instance.findProxyValue, 'PROXY 2.2.2.2:80');
    expect(ProxyService.instance.rotate(), isTrue);
    expect(ProxyService.instance.current, '1.1.1.1:80');
  });

  test('tanpa proxy aktif, koneksi langsung', () async {
    expect(ProxyService.instance.findProxyValue, 'DIRECT');
  });
}
