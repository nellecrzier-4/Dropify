import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/pixeldrain_api.dart';

enum UploadStatus { uploading, done, error }

class UploadTask {
  final String name;
  final int size;
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
  DriveController(this.api) : downloads = DownloadService(api);

  final PixeldrainApi api;

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

  Future<void> pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;
      final task = UploadTask(f.name, f.size);
      uploads.insert(0, task);
      notifyListeners();
      try {
        await api.uploadFile(path, f.name, (sent, total) {
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
    await refresh();
  }

  @override
  void dispose() {
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
    if (item.fsPath.isEmpty) return 'Item ini tidak bisa diganti nama.';
    try {
      await api.rename(item.fsPath, newName);
      return null;
    } on PixeldrainException catch (e) {
      return e.message;
    }
  }

  /// Hapus file/folder filesystem.
  Future<String?> deleteFsItem(PdItem item) async {
    if (item.fsPath.isEmpty) return 'Item ini tidak bisa dihapus.';
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
    if (id == null) return 'File ini tidak bisa dihapus dari sini.';
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
