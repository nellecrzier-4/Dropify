import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../l10n/locale_controller.dart';
import '../utils/file_types.dart';
import 'native_downloads.dart';

enum GofileUploadStatus { queued, uploading, done, error }

/// Satu berkas yang sedang diunggah ke akun Gofile.
class GofileUploadTask {
  GofileUploadTask({
    required this.id,
    required this.name,
    required this.size,
    required this.notifyId,
  });

  final String id;
  final String name;
  final int size;
  final int notifyId;

  int sent = 0;
  double speed = 0;
  GofileUploadStatus status = GofileUploadStatus.queued;
  String? error;

  /// Tautan halaman unduhan yang dibalas Gofile setelah selesai.
  String? downloadPage;

  DateTime _lastTick = DateTime.now();
  int _lastBytes = 0;

  bool get isActive =>
      status == GofileUploadStatus.queued ||
      status == GofileUploadStatus.uploading;

  double get progress {
    if (status == GofileUploadStatus.done) return 1;
    if (size <= 0) return 0;
    return (sent / size).clamp(0.0, 1.0);
  }

  Duration? get eta {
    if (speed <= 0 || size <= 0) return null;
    final left = size - sent;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / speed).round());
  }
}

/// Unggah berkas ke akun Gofile lewat API resmi mereka.
///
/// Dipakai saat pengguna menekan tombol unggah di halaman Gofile: berkasnya
/// diunggah aplikasi (bukan WebView), jadi tetap jalan di latar belakang lewat
/// foreground service dan progresnya muncul di HomeTab + notifikasi sistem.
class GofileUploadService extends ChangeNotifier {
  GofileUploadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                // Unggahan besar butuh waktu lama tanpa timeout tetap.
                receiveTimeout: const Duration(minutes: 30),
                sendTimeout: null,
                validateStatus: (_) => true,
              ),
            );

  /// Instance bersama, dipakai UI (HomeTab) dan layar WebView.
  static final GofileUploadService instance = GofileUploadService();

  final List<GofileUploadTask> tasks = <GofileUploadTask>[];
  final Dio _dio;

  String? _server;
  int _seq = 0;
  int _notifySeq = 0;
  DateTime _lastServiceUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  int get activeCount => tasks.where((t) => t.isActive).length;
  bool get hasActive => activeCount > 0;

  /// Pilih server unggah Gofile (hasilnya di-cache per sesi).
  Future<String> _pickServer() async {
    final cached = _server;
    if (cached != null) return cached;
    final res = await _dio.get<Map<String, dynamic>>(
      'https://api.gofile.io/servers',
    );
    final data = res.data?['data'];
    final servers = data is Map ? data['servers'] : null;
    if (servers is List && servers.isNotEmpty) {
      final first = servers.first;
      if (first is Map && first['name'] != null) {
        _server = first['name'].toString();
        return _server!;
      }
    }
    throw GofileUploadException(
      LocaleController.instance.strings.uploadServerUnavailable,
    );
  }

  /// Unggah satu berkas. Mengembalikan tugas; selesai saat unggahan berakhir.
  Future<GofileUploadTask> upload({
    required String path,
    required String name,
    required String token,
    String? folderId,
  }) async {
    final file = File(path);
    final size = await file.length();
    final task = GofileUploadTask(
      id: 'up${DateTime.now().microsecondsSinceEpoch}_${_seq}',
      name: name,
      size: size,
      notifyId: 5200 + _notifySeq++,
    );
    tasks.insert(0, task);
    task.status = GofileUploadStatus.uploading;
    _notify();
    _startService(task);

    try {
      final server = await _pickServer();
      final form = FormData();
      form.fields.add(MapEntry('token', token));
      if (folderId != null && folderId.isNotEmpty) {
        form.fields.add(MapEntry('folderId', folderId));
      }
      form.files.add(
        MapEntry('file', await MultipartFile.fromFile(path, filename: name)),
      );

      final res = await _dio.post<Map<String, dynamic>>(
        'https://$server.gofile.io/contents/uploadfile',
        data: form,
        options: Options(
          headers: const {'Accept': 'application/json'},
          sendTimeout: null,
          receiveTimeout: const Duration(minutes: 30),
        ),
        onSendProgress: (sent, total) {
          // FormData menambahkan header multipart, jadi pakai ukuran berkas
          // sebagai acuan supaya angkanya tidak melebihi 100%.
          task.sent = math.min(sent, size);
          _reportProgress(task);
        },
      );

      final body = res.data ?? const <String, dynamic>{};
      if ((body['status'] ?? '') != 'ok') {
        throw GofileUploadException((body['status'] ?? 'gagal').toString());
      }
      final data = body['data'];
      if (data is Map && data['downloadPage'] != null) {
        task.downloadPage = data['downloadPage'].toString();
      }
      task
        ..sent = size
        ..status = GofileUploadStatus.done
        ..speed = 0;
      NativeDownloads.notifyDownload(
        id: task.notifyId,
        title: task.name,
        text: formatSize(size),
        progress: 1,
        done: true,
      );
      _notify();
      return task;
    } catch (e) {
      task
        ..status = GofileUploadStatus.error
        ..speed = 0
        ..error = _friendlyError(e);
      NativeDownloads.notifyDownload(
        id: task.notifyId,
        title: task.name,
        text: '',
        progress: 0,
        error: task.error,
      );
      _notify();
      return task;
    }
  }

  /// Unggah beberapa berkas berurutan supaya koneksi tidak berebut.
  Future<void> uploadAll({
    required List<NativeUploadSource> sources,
    required String token,
    String? folderId,
  }) async {
    for (final source in sources) {
      if (!await File(source.path).exists()) continue;
      await upload(
        path: source.path,
        name: source.name,
        token: token,
        folderId: folderId,
      );
    }
  }

  void clearFinished() {
    tasks.removeWhere((t) => !t.isActive);
    _notify();
  }

  void _reportProgress(GofileUploadTask task) {
    final now = DateTime.now();
    final elapsed = now.difference(task._lastTick).inMilliseconds;
    if (elapsed >= 500) {
      final delta = task.sent - task._lastBytes;
      final instant = delta <= 0 ? 0.0 : delta * 1000 / elapsed;
      task.speed = task.speed <= 0 ? instant : task.speed * 0.6 + instant * 0.4;
      task._lastTick = now;
      task._lastBytes = task.sent;
      NativeDownloads.notifyDownload(
        id: task.notifyId,
        title: task.name,
        text: task.size > 0
            ? '${formatSize(task.sent)} / ${formatSize(task.size)}'
            : formatSize(task.sent),
        progress: task.progress,
      );
    }
    _notify();
  }

  void _notify() {
    _syncService();
    notifyListeners();
  }

  void _startService(GofileUploadTask task) {
    NativeDownloads.startTransferService(
      '${task.name} · mengunggah',
    );
  }

  /// Foreground service hidup selama masih ada unggahan berjalan.
  void _syncService() {
    final active = tasks.where((t) => t.isActive).toList();
    if (active.isEmpty) {
      NativeDownloads.stopTransferService();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastServiceUpdate).inMilliseconds < 1500) return;
    _lastServiceUpdate = now;
    final first = active.first;
    final text = active.length == 1
        ? '${first.name} · ${(first.progress * 100).round()}%'
        : '${active.length} berkas · ${(first.progress * 100).round()}%';
    NativeDownloads.updateTransferService(text);
  }

  String _friendlyError(Object? error) {
    final s = LocaleController.instance.strings;
    if (error is GofileUploadException) return error.message;
    if (error is DioException) {
      final code = error.response?.statusCode ?? 0;
      if (code == 401) return s.uploadDenied;
      if (code == 429) return s.serverRateLimited;
      if (code >= 500) return s.serverError(code);
      return error.message ?? s.uploadFailed;
    }
    return error?.toString() ?? s.uploadFailed;
  }
}

/// Berkas lokal yang siap diunggah.
class NativeUploadSource {
  const NativeUploadSource({required this.path, required this.name});

  final String path;
  final String name;
}

class GofileUploadException implements Exception {
  GofileUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
