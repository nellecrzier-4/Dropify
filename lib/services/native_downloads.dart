import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';

/// Hasil enqueue di DownloadManager Android.
class NativeDownloadHandle {
  const NativeDownloadHandle({
    required this.id,
    required this.name,
    required this.path,
  });

  final int id;
  final String name;

  /// Path publik hasil download, mis. /storage/emulated/0/Download/Dropify/a.zip
  final String path;
}

class NativeDownloadState {
  const NativeDownloadState({
    required this.state,
    required this.received,
    required this.total,
    this.error,
    this.uri,
  });

  /// pending | running | paused | done | failed | unknown
  final String state;
  final int received;
  final int total;
  final String? error;
  final String? uri;

  bool get isDone => state == 'done';
  bool get isFailed => state == 'failed';
  bool get isActive =>
      state == 'running' || state == 'pending' || state == 'paused';

  double get progress {
    if (total <= 0) return 0;
    return (received / total).clamp(0.0, 1.0);
  }
}

/// Berkas lokal hasil pemilih Android.
class LocalFile {
  const LocalFile({required this.path, required this.name, required this.size});

  final String path;
  final String name;

  /// Ukuran menurut provider (0 kalau tidak diketahui).
  final int size;
}

class NativeDownloadException implements Exception {
  NativeDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Jembatan ke DownloadManager Android (lihat MainActivity.kt).
///
/// Semua file mendarat di /storage/emulated/0/Download/Dropify dan progresnya
/// tampil sebagai notifikasi sistem.
class NativeDownloads {
  static const MethodChannel _channel = MethodChannel('com.nel.dropify/native');

  /// Teks error sesuai bahasa aktif.
  static AppStrings get _s => LocaleController.instance.strings;

  /// Folder tujuan yang dipakai aplikasi.
  static const String subdir = 'Dropify';
  static const String folderPath = '/storage/emulated/0/Download/Dropify';

  static Future<NativeDownloadHandle> enqueue({
    required String url,
    required String name,
    String? mime,
    Map<String, String> headers = const {},
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('enqueue', {
        'url': url,
        'name': name,
        'mime': mime,
        'subdir': subdir,
        'headers': headers,
      });
      if (res == null) {
        throw NativeDownloadException(_s.downloaderNotResponding);
      }
      return NativeDownloadHandle(
        id: (res['id'] as num).toInt(),
        name: res['name']?.toString() ?? name,
        path: res['path']?.toString() ?? folderPath,
      );
    } on PlatformException catch (e) {
      throw NativeDownloadException(e.message ?? _s.downloadStartFailed);
    } on MissingPluginException {
      throw NativeDownloadException(_s.downloaderUnavailable);
    }
  }

  static Future<NativeDownloadState?> query(int id) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('query', {'id': id});
      if (res == null) return null;
      return NativeDownloadState(
        state: res['state']?.toString() ?? 'unknown',
        received: (res['received'] as num?)?.toInt() ?? 0,
        total: (res['total'] as num?)?.toInt() ?? 0,
        error: res['error']?.toString(),
        uri: res['uri']?.toString(),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> cancel(int id) async {
    try {
      return await _channel.invokeMethod<bool>('cancel', {'id': id}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openFile(int id) async {
    try {
      return await _channel.invokeMethod<bool>('openFile', {'id': id}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Buka pemilih berkas Android dan kembalikan `content://` URI apa adanya.
  ///
  /// Dipakai input file di WebView: URI diteruskan langsung ke WebView tanpa
  /// menyalin berkas ke cache aplikasi (menyalin berkas 8 GB butuh menit).
  /// null berarti kanal native tidak tersedia; daftar kosong berarti pengguna
  /// membatalkan pemilihan.
  static Future<List<String>?> pickDocuments({bool multiple = false}) async {
    try {
      final res = await _channel.invokeMethod<List<Object?>>('pickFiles', {
        'multiple': multiple,
      });
      return (res ?? const <Object?>[])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Callback progres dari downloader native (FileDownloader.kt).
  static bool _listenerAttached = false;

  static void _attachListener() {
    if (_listenerAttached) return;
    _listenerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'downloadProgress') return null;
      final raw = call.arguments;
      if (raw is Map) {
        _onNativeEvent(Map<String, dynamic>.from(raw));
      }
      return null;
    });
  }

  static void _onNativeEvent(Map<String, dynamic> event) {
    try {
      onNativeProgress?.call(event);
    } catch (_) {}
  }

  static void Function(Map<String, dynamic> event)? onNativeProgress;

  /// Mulai unduhan di proses native (tanpa menulis dari Dart).
  static Future<bool> startNativeDownload({
    required String id,
    required String url,
    required String name,
    Map<String, String> headers = const {},
  }) async {
    _attachListener();
    try {
      return await _channel.invokeMethod<bool>('downloadStart', {
            'id': id,
            'url': url,
            'name': name,
            'headers': headers,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> cancelNativeDownload(String id) async {
    try {
      await _channel.invokeMethod<bool>('downloadCancel', {'id': id});
    } catch (_) {}
  }

  /// Path nyata + nama + ukuran dari URI pemilih berkas.
  ///
  /// Kalau provider tidak memberi path (mis. dokumen di cloud), berkas disalin
  /// ke cache di sisi native dan path salinan itu yang dikembalikan.
  static Future<LocalFile?> resolveDocument(String uri) async {
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('resolveDocument', {'uri': uri});
      final path = res?['path']?.toString() ?? '';
      if (path.isEmpty) return null;
      return LocalFile(
        path: path,
        name: res?['name']?.toString() ?? path.split('/').last,
        size: (res?['size'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Isi ekor dropify.log + crash.log (untuk layar diagnosa).
  static Future<String> readLogs() async {
    try {
      final res = await _channel.invokeMethod<Object?>('readLogs');
      return res?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Versi aplikasi yang benar-benar terpasang, mis. "1.7.10 (26)".
  static Future<String> appVersion() async {
    try {
      final res = await _channel.invokeMethod<Object?>('appVersion');
      final text = res?.toString() ?? '';
      return text.isEmpty ? '-' : text;
    } catch (_) {
      return '-';
    }
  }

  /// Ruang kosong di penyimpanan bersama (byte); -1 kalau tidak diketahui.
  static Future<int> freeSpace() async {
    try {
      final res = await _channel.invokeMethod<Object?>('freeSpace');
      if (res is num) return res.toInt();
      return -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> scanFile(String path) async {
    try {
      await _channel.invokeMethod<bool>('scanFile', {'path': path});
    } catch (_) {}
  }

  static Future<void> startTransferService(String text) async {
    try {
      await _channel.invokeMethod<bool>('startTransferService', {'text': text});
    } catch (_) {}
  }

  static Future<void> updateTransferService(String text) async {
    try {
      await _channel.invokeMethod<bool>('updateTransferService', {'text': text});
    } catch (_) {}
  }

  static Future<void> stopTransferService() async {
    try {
      await _channel.invokeMethod<bool>('stopTransferService');
    } catch (_) {}
  }

  static Future<void> restartApp() async {
    try {
      await _channel.invokeMethod<bool>('restartApp');
    } catch (_) {}
  }

  static Future<void> shareText(String text, {String title = 'Dropify'}) async {
    try {
      await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'title': title,
      });
    } catch (_) {}
  }

  static Future<bool> openPath(String path, {String? mime}) async {
    try {
      return await _channel.invokeMethod<bool>('openPath', {
            'path': path,
            'mime': mime,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> notifyDownload({
    required int id,
    required String title,
    required String text,
    required double progress,
    bool done = false,
    String? error,
  }) async {
    try {
      await _channel.invokeMethod<bool>('notifyDownload', {
        'id': id,
        'title': title,
        'text': text,
        'progress': progress,
        'done': done,
        'error': error,
      });
    } catch (_) {}
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _channel.invokeMethod<bool>('cancelNotification', {'id': id});
    } catch (_) {}
  }

  static Future<bool> notificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermissions') ?? true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
