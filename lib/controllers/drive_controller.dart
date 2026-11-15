import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/pixeldrain_api.dart';
import '../services/transfer_session.dart';

enum UploadStatus { uploading, done, error }

class UploadTask {
  final String name;
  final int size;
  int parts = 1;
  int currentPart = 1;
  double progress = 0;
  double speed = 0;
  int sent = 0;
  UploadStatus status = UploadStatus.uploading;
  String? error;

  DateTime _lastTick = DateTime.now();
  int _lastBytes = 0;

  UploadTask(this.name, this.size);
}

/// State utama aplikasi: daftar file dari Pixeldrain + status sync + upload.
class DriveController extends ChangeNotifier {
  DriveController(this.api) : downloads = DownloadService(api) {
    // Unduhan dari layar lain (WebView Gofile) memakai instance yang sama,
    // supaya pill HomeTab dan sheet Transfers menampilkannya.
    DownloadService.shared = downloads;
  }

  final PixeldrainApi api;

  /// Teks sesuai bahasa aktif (tanpa BuildContext).
  AppStrings get _s => LocaleController.instance.strings;

  /// Manajer download (link bypass + progres unduhan).
  final DownloadService downloads;

  /// Download sebuah file lewat link bypass.
  Future<DownloadTask?> downloadFile(PdItem item) => downloads.download(item);

  List<PdItem> files = const [];
  String username = '';
  bool loading = false;
  bool loaded = false;
  bool sessionExpired = false;
  String? error;
  DateTime? lastSync;
  final List<UploadTask> uploads = [];

  bool get hasActiveUpload =>
      uploads.any((t) => t.status == UploadStatus.uploading);

  bool get hasActiveTransfer => hasActiveUpload || downloads.hasActive;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final filesFuture = api.listUserFiles();
      final infoFuture = api.getUserInfo();
      files = await filesFuture;
      final info = await infoFuture;
      username = info?['username']?.toString() ?? username;
      lastSync = DateTime.now();
      sessionExpired = false;
    } on PixeldrainException catch (e) {
      error = e.message;
      sessionExpired = e.unauthorized;
    } catch (e) {
      error = 'Error: $e';
    } finally {
      loading = false;
      loaded = true;
      notifyListeners();
    }
  }

  /// Batas per file di Pixeldrain 8 GB. File lebih besar dipecah otomatis
  /// menjadi beberapa bagian (tetap file terpisah, bukan menembus limit server).
  static const int maxPartSize = 7 * 1024 * 1024 * 1024;

  Future<void> _uploadOne(
    UploadTask task,
    String path,
    String name,
    void Function(int sent, int total) onProgress,
  ) async {
    final file = File(path);
    final size = await file.length();

    if (size <= maxPartSize) {
      task
        ..parts = 1
        ..currentPart = 1;
      await api.uploadFile(path, name, onProgress);
      return;
    }

    final parts = (size / maxPartSize).ceil();
    task.parts = parts;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';

    var uploaded = 0;
    for (var i = 0; i < parts; i++) {
      final start = i * maxPartSize;
      final end = math.min(start + maxPartSize, size);
      task.currentPart = i + 1;
      notifyListeners();

      final partName = '$stem.part${i + 1}$ext';
      final base = uploaded;
      // Dialirkan langsung dari file asli — tidak ada salinan di cache.
      await api.uploadRange(file, start, end, partName, (sent, total) {
        onProgress(base + sent, size);
      });
      uploaded += end - start;
    }
  }

  Future<void> pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    TransferSession.setUploadsActive(true, downloadsActive: downloads.hasActive);
    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;
      final task = UploadTask(f.name, f.size);
      uploads.insert(0, task);
      notifyListeners();
      try {
        await _uploadOne(task, path, f.name, (sent, total) {
          if (total <= 0) return;
          task.sent = sent;
          final p = sent / total;
          final now = DateTime.now();
          final elapsed = now.difference(task._lastTick).inMilliseconds;
          var changed = false;
          if (elapsed >= 500) {
            final delta = sent - task._lastBytes;
            final instant = delta <= 0 ? 0.0 : delta * 1000 / elapsed;
            // Rata-rata bergerak supaya angka kecepatan tidak melonjak.
            task.speed =
                task.speed <= 0 ? instant : task.speed * 0.65 + instant * 0.35;
            task._lastTick = now;
            task._lastBytes = sent;
            changed = true;
          }
          if (p - task.progress >= 0.01 || p >= 1 || changed) {
            task.progress = p;
            notifyListeners();
          }
        });
        task.progress = 1;
        task.speed = 0;
        task.status = UploadStatus.done;
      } on PixeldrainException catch (e) {
        task.status = UploadStatus.error;
        task.error = e.message;
      } catch (e) {
        task.status = UploadStatus.error;
        task.error = '$e';
      }
      notifyListeners();
    }
    TransferSession.setUploadsActive(false, downloadsActive: downloads.hasActive);
    await refresh();
  }

  @override
  void dispose() {
    if (identical(DownloadService.shared, downloads)) {
      DownloadService.shared = null;
    }
    downloads.dispose();
    super.dispose();
  }

  /// Buat folder di filesystem Pixeldrain.
  Future<String?> createFolder(List<String> parent, String name) async {
    try {
      await api.createDir(parent, name);
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    }
  }

  /// Ganti nama file/folder filesystem.
  Future<String?> renameFsItem(PdItem item, String newName) async {
    if (item.fsPath.isEmpty) return _s.itemCannotRename;
    try {
      await api.rename(item.fsPath, newName);
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    }
  }

  /// Hapus file/folder filesystem.
  Future<String?> deleteFsItem(PdItem item) async {
    if (item.fsPath.isEmpty) return _s.itemCannotDelete;
    try {
      await api.deleteFs(item.fsPath, recursive: item.isDir);
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    }
  }

  /// Upload file ke dalam folder filesystem.
  Future<String?> uploadToFolder(
    List<String> parent,
    String path,
    String name,
  ) async {
    try {
      await api.uploadToDir(parent, path, name, (sent, total) {});
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> deleteItem(PdItem item) async {
    final id = item.id;
    if (id == null) return _s.fileCannotDeleteHere;
    try {
      await api.deleteFile(id);
      files = files.where((f) => f.id != id).toList();
      notifyListeners();
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    }
  }
}
