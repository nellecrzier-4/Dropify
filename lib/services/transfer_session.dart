import '../l10n/locale_controller.dart';
import 'native_downloads.dart';

/// Menjaga satu foreground service selama masih ada upload atau download,
/// supaya transfer tetap jalan saat aplikasi ditinggalkan.
class TransferSession {
  TransferSession._();

  static bool _uploadsActive = false;
  static bool _downloadsActive = false;
  static bool _running = false;

  static void setUploadsActive(bool value, {bool downloadsActive = false}) {
    _uploadsActive = value;
    _downloadsActive = downloadsActive;
    _sync();
  }

  static void setDownloadsActive(bool value) {
    _downloadsActive = value;
    _sync();
  }

  static void _sync() {
    if (_uploadsActive || _downloadsActive) {
      if (!_running) {
        _running = true;
        NativeDownloads.startTransferService(
          LocaleController.instance.strings.transferRunning);
      }
    } else if (_running) {
      _running = false;
      NativeDownloads.stopTransferService();
    }
  }
}
