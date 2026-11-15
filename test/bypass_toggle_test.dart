import 'package:dropify/services/pixeldrain_bypass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sakelar bypass tersimpan dan dipulihkan', () async {
    await PixeldrainBypass.setEnabled(false);
    expect(PixeldrainBypass.enabled, isFalse);
    expect(PixeldrainBypass.linkForFileId('abc'), isNull,
        reason: 'tanpa bypass, pakai server Pixeldrain');

    await PixeldrainBypass.setEnabled(true);
    expect(PixeldrainBypass.enabled, isTrue);
    expect(PixeldrainBypass.linkForFileId('abc'), contains('abc'));

    // Nilai bertahan setelah "restart" (load membaca prefs).
    await PixeldrainBypass.setEnabled(false);
    await PixeldrainBypass.load();
    expect(PixeldrainBypass.enabled, isFalse);
  });
}
