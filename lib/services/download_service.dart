import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/pd_item.dart';
import '../utils/file_types.dart';
import 'app_settings.dart';
import 'transfer_session.dart';
import 'native_downloads.dart';
import 'pixeldrain_api.dart';
import 'pixeldrain_bypass.dart';

enum DownloadStatus { preparing, queued, downloading, done, error, canceled }

/// Satu file yang sedang / sudah diunduh.
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.key,
    required this.item,
    required this.name,
    required this.directUrl,
    required this.directHeaders,
    required this.notifyId,
    this.urlOverride,
    int sizeHint = 0,
  }) : size = sizeHint;

  final String id;
  final String key;
  final PdItem item;
  final String directUrl;
  final Map<String, String> directHeaders;
  final int notifyId;

  /// Link bypass siap pakai (dipakai saat download dari link orang lain).
  final String? urlOverride;

  String name;
  int size;
  int received = 0;
  double speed = 0;
  double peakSpeed = 0;
  DownloadStatus status = DownloadStatus.preparing;
  String? error;

  /// Path publik file, mis. /storage/emulated/0/Download/Dropify/a.zip
  String? path;

  /// Link yang benar-benar dipakai (sudah resolve redirect).
  String? url;
  bool viaBypass = false;
  String? bypassError;
  int attempts = 0;

  CancelToken? cancelToken;
  bool canceled = false;
  bool waiting = false;



  DateTime? startedAt;
  DateTime? endedAt;

  DateTime _lastTick = DateTime.now();
  DateTime _lastChannelTick = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastBytes = 0;

  bool get isActive =>
      status == DownloadStatus.preparing ||
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading;

  double get progress {
    if (status == DownloadStatus.done) return 1;
    if (size <= 0) return 0;
    return (received / size).clamp(0.0, 1.0);
  }

  Duration? get eta {
    if (speed <= 0 || size <= 0) return null;
    final left = size - received;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / speed).round());
  }
}

/// Hasil pengecekan sebuah link sebelum diunduh.
class ProbeResult {
  const ProbeResult.ok(
    this.url, {
    this.size = 0,
    this.ranges = false,
  }) : error = null;

  const ProbeResult.fail(this.error)
      : url = null,
        size = 0,
        ranges = false;

  /// URL final setelah redirect (node CDN tertentu).
  final String? url;
  final String? error;

  /// Ukuran file menurut server (0 kalau tidak diketahui).
  final int size;

  /// Server mendukung HTTP Range (bisa download paralel + resume).
  final bool ranges;

  bool get ok => error == null;
}

typedef ProbeFn = Future<ProbeResult> Function(
  String url,
  Map<String, String> headers,
);

class _RetryableError implements Exception {
  _RetryableError(this.message);
  final String message;
}

/// Header yang menyerupai browser. Sebagian CDN/mirror membalas 403 untuk
/// request tanpa User-Agent atau tanpa Referer.
const Map<String, String> _browserHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  'Referer': 'https://pixeldrain.com/',
};

/// Server mengabaikan header Range (balas 200, bukan 206).
class _RangeUnsupported implements Exception {}

/// Satu potongan kecil file; diambil bergiliran oleh worker.
/// Mutex async sederhana untuk menyerialkan penulisan ke satu file handle.
class _AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}

class _Chunk {
  _Chunk(this.start, this.end);

  final int start;
  final int end;
  int received = 0;

  int get length => end - start + 1;
  int get offset => start + received;
  bool get done => offset > end;
}

/// Dipakai kalau server mengabaikan header Range.
/// Downloader di dalam aplikasi.
///
/// - Satu link bypass baru per download, dicek dulu sebelum dipakai.
/// - Ditulis langsung ke /storage/emulated/0/Download/Dropify.
/// - Kalau koneksi putus, unduhan **dilanjutkan** dari byte terakhir (HTTP
///   Range), bukan diulang dari nol.
/// - Progres dikirim ke notifikasi sistem.
class DownloadService extends ChangeNotifier {
  DownloadService(
    this.api, {
    ProbeFn? probe,
    Dio? dio,
    String? folderOverride,
    int parallelMinSize = 16 * 1024 * 1024,
    int minSegmentSize = 4 * 1024 * 1024,
  })  : _probeOverride = probe,
        _folderOverride = folderOverride,
        _parallelMinSize = parallelMinSize,
        _minSegmentSize = minSegmentSize,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: null,
                followRedirects: true,
                maxRedirects: 6,
              ),
            );

  final PixeldrainApi api;
  final ProbeFn? _probeOverride;
  final String? _folderOverride;
  final Dio _dio;

  final List<DownloadTask> tasks = <DownloadTask>[];

  int _seq = 0;
  bool _disposed = false;
  DateTime _lastServiceUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  int get activeCount => tasks.where((t) => t.isActive).length;
  bool get hasActive => activeCount > 0;

  String get folderPath => _folderOverride ?? NativeDownloads.folderPath;

  Future<DownloadTask?> download(PdItem item, {String? urlOverride}) async {
    if (item.isDir) return null;

    final fileId = (item.id ?? '').trim();
    final key = fileId.isNotEmpty ? 'id:$fileId' : 'fs:${item.fsPath.join('/')}';
    for (final t in tasks) {
      if (t.key == key && t.isActive) return t;
    }

    final task = DownloadTask(
      id: 'dl${DateTime.now().microsecondsSinceEpoch}_${_seq}',
      key: key,
      item: item,
      name: item.name,
      directUrl: _directUrl(item, fileId),
      directHeaders: api.authHeaders,
      notifyId: 4200 + _seq++,
      urlOverride: urlOverride,
      sizeHint: item.size,
    );

    tasks.insert(0, task);
    _notify();

    if (!await _ensureStorage()) {
      task
        ..status = DownloadStatus.error
        ..error = 'storage_permission'
        ..endedAt = DateTime.now();
      _notify();
      return task;
    }

    await _resolveAndRun(task);
    return task;
  }

  Future<void> retry(String taskId) async {
    final t = _byId(taskId);
    if (t == null || t.isActive) return;
    _reset(t);
    _notify();
    if (!await _ensureStorage()) {
      t
        ..status = DownloadStatus.error
        ..error = 'storage_permission';
      _notify();
      return;
    }
    await _resolveAndRun(t);
  }

  Future<void> retryWithoutBypass(String taskId) async {
    final t = _byId(taskId);
    if (t == null || t.isActive) return;
    _reset(t);
    _notify();
    await _run(t, t.directUrl, viaBypass: false);
  }

  void cancel(String taskId) {
    final t = _byId(taskId);
    if (t == null || !t.isActive) return;
    t
      ..canceled = true
      ..status = DownloadStatus.canceled
      ..speed = 0
      ..endedAt = DateTime.now();
    t.cancelToken?.cancel('dibatalkan');
    NativeDownloads.cancelNotification(t.notifyId);
    _notify();
  }

  void clearFinished() {
    tasks.removeWhere((t) => !t.isActive);
    _notify();
  }

  Future<void> openFile(DownloadTask task) async {
    final path = task.path;
    if (path == null) return;
    await NativeDownloads.openPath(path, mime: task.item.mime);
  }

  String? linkFor(PdItem item) {
    final fileId = (item.id ?? '').trim();
    return PixeldrainBypass.linkForFileId(fileId.isEmpty ? null : fileId) ??
        _directUrl(item, fileId);
  }

  String _directUrl(PdItem item, String fileId) {
    if (fileId.isNotEmpty) {
      return 'https://pixeldrain.com/api/file/$fileId?download';
    }
    final path = item.fsPath.map((s) => '/${Uri.encodeComponent(s)}').join();
    return 'https://pixeldrain.com/api/filesystem/me$path?download';
  }

  Future<bool> _ensureStorage() async {
    if (await NativeDownloads.hasAllFilesAccess()) return true;
    await NativeDownloads.requestAllFilesAccess();
    return NativeDownloads.hasAllFilesAccess();
  }

  void _reset(DownloadTask t) {
    t
      ..status = DownloadStatus.preparing
      ..error = null
      ..received = 0
      ..speed = 0
      ..url = null
      ..viaBypass = false
      ..bypassError = null
      ..attempts = 0
      ..canceled = false
      ..waiting = false
      ..cancelToken = null
      ..path = null
      ..startedAt = null
      ..endedAt = null;
  }

  Future<void> _resolveAndRun(DownloadTask task) async {
    if (_disposed || task.canceled) return;

    final override = task.urlOverride;
    if (override != null) {
      final probe = await _probeUrl(override, const {});
      if (_disposed || task.canceled) return;
      if (probe.ok) {
        await _run(
          task,
          probe.url ?? override,
          nodes: [probe.url ?? override],
          viaBypass: true,
          knownSize: probe.size,
          supportsRanges: probe.ranges,
        );
        return;
      }
      task
        ..status = DownloadStatus.error
        ..error = 'Link: ${probe.error ?? 'tidak bisa diakses'}'
        ..endedAt = DateTime.now();
      _notify();
      return;
    }

    final fileId = (task.item.id ?? '').trim();
    final bypass = PixeldrainBypass.linkForFileId(fileId.isEmpty ? null : fileId);

    if (bypass != null) {
      final nodes = <String>[];
      ProbeResult? first;
      ProbeResult? last;

      // Beberapa percobaan: redirect bisa memberi node CDN berbeda, dan
      // beberapa node dipakai bergantian supaya tidak di-throttle.
      for (var i = 0; i < 3; i++) {
        final link = i == 0
            ? bypass
            : (PixeldrainBypass.linkForFileId(
                  (task.item.id ?? '').trim().isEmpty ? null : task.item.id,
                ) ??
                bypass);
        final probe = await _probeUrl(link, const {});
        if (_disposed || task.canceled) return;
        last = probe;
        if (probe.ok) {
          first ??= probe;
          final url = probe.url ?? link;
          if (!nodes.contains(url)) nodes.add(url);
        } else {
          task.bypassError = probe.error;
        }
        if (nodes.length >= 2) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (first != null) {
        await _run(
          task,
          nodes.first,
          nodes: nodes,
          viaBypass: true,
          knownSize: first.size,
          supportsRanges: first.ranges,
        );
        return;
      }
      task.bypassError = last?.error ?? 'gagal';
      if (task.bypassError == 'rate_limited') {
        task
          ..status = DownloadStatus.error
          ..error = 'pixeldrain_rate_limited'
          ..speed = 0
          ..endedAt = DateTime.now();
        NativeDownloads.cancelNotification(task.notifyId);
        _notify();
        return;
      }
    }

    final directProbe = await _probeUrl(task.directUrl, task.directHeaders);
    if (_disposed || task.canceled) return;
    if (directProbe.ok) {
      await _run(
        task,
        directProbe.url ?? task.directUrl,
        nodes: [directProbe.url ?? task.directUrl],
        viaBypass: false,
        knownSize: directProbe.size,
        supportsRanges: directProbe.ranges,
      );
      return;
    }

    final directError = directProbe.error ?? 'gagal';
    final rateLimited =
        directError == 'rate_limited' || task.bypassError == 'rate_limited';
    task
      ..status = DownloadStatus.error
      ..error = rateLimited
          ? 'pixeldrain_rate_limited'
          : (task.bypassError == null
              ? 'Pixeldrain: $directError'
              : 'Bypass: ${task.bypassError} · Pixeldrain: $directError')
      ..endedAt = DateTime.now();
    _notify();
  }

  final int _parallelMinSize;
  final int _minSegmentSize;

  Future<void> _run(
    DownloadTask task,
    String url, {
    List<String>? nodes,
    required bool viaBypass,
    int knownSize = 0,
    bool supportsRanges = false,
  }) async {
    if (_disposed || task.canceled) return;

    final dir = Directory(folderPath);
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {
      _fail(task, 'storage_permission');
      return;
    }

    final target = await _uniqueFile(dir, task.name);
    final part = File('${target.path}.part');

    task
      ..path = target.path
      ..url = url
      ..viaBypass = viaBypass
      ..status = DownloadStatus.downloading
      ..startedAt = DateTime.now()
      .._lastTick = DateTime.now()
      .._lastBytes = 0
      ..received = 0
      ..attempts = 0;
    _notify();

    try {
      if (supportsRanges && knownSize >= _parallelMinSize) {
        try {
          await _runParallel(task, part, knownSize, nodes ?? [url]);
        } on _RangeUnsupported {
          try {
            if (await part.exists()) await part.delete();
          } catch (_) {}
          await _runSingle(task, part);
        }
      } else {
        await _runSingle(task, part);
      }

      if (task.canceled) return;

      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      NativeDownloads.scanFile(target.path);
      DownloadHistory.instance.add(
        DownloadRecord(
          name: task.name,
          path: target.path,
          size: await target.length(),
          time: DateTime.now(),
        ),
      );

      task
        ..status = DownloadStatus.done
        ..size = await target.length()
        ..received = task.size
        ..speed = 0
        ..endedAt = DateTime.now();
      NativeDownloads.notifyDownload(
        id: task.notifyId,
        title: task.name,
        text: formatSize(task.size),
        progress: 1,
        done: true,
      );
      _notify();
    } catch (e) {
      if (task.canceled) {
        NativeDownloads.cancelNotification(task.notifyId);
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
        return;
      }
      _fail(task, _friendlyError(e));
    }
  }

  void _fail(DownloadTask task, String message) {
    task
      ..status = DownloadStatus.error
      ..error = message
      ..speed = 0
      ..waiting = false
      ..endedAt = DateTime.now();
    NativeDownloads.notifyDownload(
      id: task.notifyId,
      title: task.name,
      text: '',
      progress: 0,
      error: message == 'storage_permission' ? 'Izin akses file diperlukan' : message,
    );
    _notify();
  }

  /// Unduhan satu koneksi dengan resume (Range) — untuk file kecil atau
  /// server yang tidak mendukung Range.
  Future<void> _runSingle(DownloadTask task, File part) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 4; attempt++) {
      if (task.canceled || _disposed) return;
      task.attempts = attempt;

      try {
        await _downloadOnce(task, task.url!, part);
        return;
      } catch (e) {
        lastError = e;
        if (task.canceled) return;
        if (attempt >= 4) break;

        task.waiting = true;
        _notify();
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
        task.waiting = false;

        final fresh = await _freshUrl(task);
        if (fresh != null) task.url = fresh;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  /// Unduhan paralel dengan antrean potongan.
  ///
  /// File ditulis lewat SATU handle [RandomAccessFile] dengan offset eksplisit.
  /// (Sebelumnya tiap potongan membuka file dalam mode append; pada file besar
  /// flag O_APPEND membuat offset diabaikan OS sehingga file membengkak dan
  /// unduhan gagal.)
  Future<void> _runParallel(
    DownloadTask task,
    File part,
    int size,
    List<String> nodes,
  ) async {
    final chunks = _planChunks(size, _chunkSize(size));
    task
      ..size = size
      ..received = 0;

    final raf = await part.open(mode: FileMode.write);
    final lock = _AsyncLock();
    final token = CancelToken();
    task.cancelToken = token;

    try {
      // Siapkan file seukuran target (sparse).
      await raf.setPosition(size - 1);
      await raf.writeByte(0);

      final workers = _workerCount(size);
      var next = 0;
      var running = 0;
      var extra = 0;
      final finished = Completer<void>();

      void checkDone() {
        if (next >= chunks.length && running == 0 && !finished.isCompleted) {
          finished.complete();
        }
      }

      Object? workerError;
      Future<void> worker(int id) async {
        running++;
        try {
          while (!task.canceled && !_disposed) {
            if (next >= chunks.length) break;
            final chunk = chunks[next++];
            await _downloadChunk(task, raf, lock, chunk, nodes, id, token);
          }
        } catch (e) {
          workerError ??= e;
        } finally {
          running--;
          checkDone();
        }
      }

      for (var i = 0; i < workers; i++) {
        unawaited(worker(i));
      }

      // Kalau kecepatan drop jauh dari puncak, tambah koneksi.
      final booster = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (finished.isCompleted) {
          timer.cancel();
          return;
        }
        if (task.canceled || _disposed || next >= chunks.length) return;
        final slow = task.peakSpeed > 0 && task.speed < task.peakSpeed * 0.65;
        if (slow && extra < 4) {
          extra++;
          unawaited(worker(100 + extra));
        }
      });

      await finished.future;
      booster.cancel();

      if (task.canceled) return;
      if (workerError != null) throw workerError!;

      final receivedSum = chunks.fold<int>(0, (a, c) => a + c.received);
      if (receivedSum < size) {
        throw _RetryableError('koneksi berhenti sebelum selesai');
      }

      await raf.flush();
      final length = await raf.length();
      if (length != size) {
        throw _RetryableError('ukuran file tidak sesuai ($length/$size byte)');
      }
      task.received = size;
    } finally {
      try {
        await raf.close();
      } catch (_) {}
    }
  }

  Future<void> _downloadChunk(
    DownloadTask task,
    RandomAccessFile raf,
    _AsyncLock lock,
    _Chunk chunk,
    List<String> nodes,
    int workerId,
    CancelToken token,
  ) async {
    var failures = 0;

    while (chunk.offset <= chunk.end) {
      if (task.canceled || _disposed) return;
      final from = chunk.offset;
      final url = nodes[(workerId + failures) % nodes.length];

      try {
        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            headers: {
              ..._browserHeaders,
              'Accept': '*/*',
              'Range': 'bytes=$from-${chunk.end}',
              if (!task.viaBypass) ...task.directHeaders,
            },
            responseType: ResponseType.stream,
            receiveTimeout: null,
            validateStatus: (_) => true,
          ),
          cancelToken: token,
        );

        final code = response.statusCode ?? 0;
        if (code == 200) throw _RangeUnsupported();
        if (code != 206) throw _RetryableError('HTTP $code');

        final buffer = BytesBuilder(copy: false);
        var writePos = from;
        try {
          await for (final data
              in response.data!.stream.timeout(const Duration(seconds: 20))) {
            if (task.canceled) return;
            buffer.add(data);
            chunk.received += data.length;
            task.received += data.length;
            if (buffer.length >= 1024 * 1024) {
              final bytes = buffer.takeBytes();
              final at = writePos;
              await lock.run(() async {
                await raf.setPosition(at);
                await raf.writeFrom(bytes);
              });
              writePos += bytes.length;
            }
            _reportProgress(task, task.received);
          }
          if (buffer.length > 0) {
            final bytes = buffer.takeBytes();
            final at = writePos;
            await lock.run(() async {
              await raf.setPosition(at);
              await raf.writeFrom(bytes);
            });
            writePos += bytes.length;
          }
        } finally {
          buffer.clear();
        }

        if (chunk.offset <= chunk.end) {
          throw _RetryableError('potongan belum selesai');
        }
      } catch (e) {
        if (task.canceled || _disposed) return;
        if (e is _RangeUnsupported) rethrow;

        failures++;
        if (failures >= 4) rethrow;

        task.waiting = true;
        _notify();
        await Future<void>.delayed(Duration(milliseconds: 350 * failures));
        task.waiting = false;
      }
    }
  }

  int _workerCount(int size) {
    final max = AppSettings.instance.connections;
    if (size >= 128 * 1024 * 1024) return max;
    if (size >= 32 * 1024 * 1024) return (max - 2).clamp(2, max);
    return (max - 4).clamp(2, max);
  }

  int _chunkSize(int size) {
    final byCount = size ~/ 240;
    final min = _minSegmentSize;
    const max = 16 * 1024 * 1024;
    if (byCount < min) return min;
    if (byCount > max) return max;
    return byCount;
  }

  List<_Chunk> _planChunks(int size, int chunkSize) {
    final chunks = <_Chunk>[];
    var cursor = 0;
    while (cursor < size) {
      final end = cursor + chunkSize - 1;
      chunks.add(_Chunk(cursor, end < size ? end : size - 1));
      cursor += chunkSize;
    }
    return chunks;
  }

  Future<String?> _freshUrl(DownloadTask task) async {
    final id = (task.item.id ?? '').trim();
    final bypass = PixeldrainBypass.linkForFileId(id.isEmpty ? null : id);
    if (bypass == null) return null;
    final probe = await _probeUrl(bypass, const {});
    return probe.ok ? (probe.url ?? bypass) : null;
  }

  Future<void> _downloadOnce(
    DownloadTask task,
    String url,
    File part,
  ) async {
    var start = 0;
    try {
      if (await part.exists()) start = await part.length();
    } catch (_) {
      start = 0;
    }

    final headers = <String, String>{..._browserHeaders, 'Accept': '*/*'};
    if (start > 0) headers['Range'] = 'bytes=$start-';
    if (!task.viaBypass) headers.addAll(task.directHeaders);

    final token = CancelToken();
    task.cancelToken = token;

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        receiveTimeout: null,
      ),
      cancelToken: token,
    );

    final code = response.statusCode ?? 0;
    if (code == 416) {
      try {
        await part.delete();
      } catch (_) {}
      throw _RetryableError('rentang tidak valid');
    }
    if (code != 200 && code != 206) {
      throw PixeldrainException('HTTP $code');
    }

    final resuming = code == 206 && start > 0;
    if (!resuming) start = 0;

    final lengthHeader =
        int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
    task.size = lengthHeader != null ? lengthHeader + start : 0;
    task.received = start;

    final sink = part.openWrite(
      mode: resuming ? FileMode.append : FileMode.write,
    );

    var received = start;
    try {
      await for (final chunk in response.data!.stream) {
        if (task.canceled) {
          throw _RetryableError('dibatalkan');
        }
        sink.add(chunk);
        received += chunk.length;
        _reportProgress(task, received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (task.size > 0 && received < task.size) {
      throw _RetryableError('koneksi berhenti sebelum selesai');
    }
    task.received = received;
  }

  void _reportProgress(DownloadTask task, int received) {
    task.received = received;
    final now = DateTime.now();
    final elapsed = now.difference(task._lastTick).inMilliseconds;
    if (elapsed >= 500) {
      final delta = received - task._lastBytes;
      final instant = delta <= 0 ? 0.0 : delta * 1000 / elapsed;
      // Rata-rata bergerak supaya angka di UI tidak naik-turun.
      task.speed = task.speed <= 0 ? instant : task.speed * 0.65 + instant * 0.35;
      if (task.speed > task.peakSpeed) task.peakSpeed = task.speed;
      task._lastTick = now;
      task._lastBytes = received;
      // Notifikasi maksimal sekali per detik supaya UI/engine tidak tersendat.
      if (now.difference(task._lastChannelTick).inMilliseconds >= 1000) {
        task._lastChannelTick = now;
        NativeDownloads.notifyDownload(
          id: task.notifyId,
          title: task.name,
          text: task.size > 0
              ? '${formatSize(received)} / ${formatSize(task.size)}'
              : formatSize(received),
          progress: task.progress,
        );
      }
      _notify();
    }
  }

  Future<File> _uniqueFile(Directory dir, String name) async {
    final wanted = _sanitize(name);
    final dot = wanted.lastIndexOf('.');
    final stem = dot > 0 ? wanted.substring(0, dot) : wanted;
    final ext = dot > 0 ? wanted.substring(dot) : '';

    for (var i = 0; i < 1000; i++) {
      final candidate = i == 0 ? wanted : '$stem ($i)$ext';
      final file = File('${dir.path}/$candidate');
      if (!await file.exists()) return file;
    }
    return File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$wanted');
  }

  String _sanitize(String name) {
    var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) clean = 'file';
    if (clean.length > 120) {
      final dot = clean.lastIndexOf('.');
      if (dot > 0) {
        final ext = clean.substring(dot);
        clean = clean.substring(0, 120 - ext.length) + ext;
      } else {
        clean = clean.substring(0, 120);
      }
    }
    if (clean.startsWith('.')) clean = '_$clean';
    return clean;
  }

  String _friendlyError(Object? error) {
    if (error == null) return 'Download gagal.';
    if (error is PixeldrainException) return error.message;
    if (error is _RetryableError) return error.message;
    if (error is DioException) {
      final code = error.response?.statusCode ?? 0;
      if (code == 404) return 'File tidak ditemukan di Pixeldrain.';
      if (code == 403) {
        return 'Server menolak (HTTP 403) — biasanya batas unduhan Pixeldrain '
            'sudah tercapai atau file dibatasi. Coba lagi nanti / buka di browser.';
      }
      if (code == 401) return 'Akses file ditolak (HTTP 401).';
      if (code == 429) return 'Server masih membatasi. Coba lagi nanti.';
      if (code >= 500) return 'Server download bermasalah (HTTP $code).';
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Koneksi timeout. Coba lagi.';
        case DioExceptionType.connectionError:
          return 'Tidak ada koneksi internet.';
        default:
          return error.message ?? 'Download gagal.';
      }
    }
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<ProbeResult> _probeUrl(String url, Map<String, String> headers) {
    final override = _probeOverride;
    if (override != null) return override(url, headers);
    return _probeWithNetwork(url, headers);
  }

  Future<ProbeResult> _probeWithNetwork(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final res = await _dio.head(
        url,
        options: Options(
          headers: {..._browserHeaders, ...headers, 'Accept': '*/*'},
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code == 200 || code == 206) {
        final size =
            int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '') ??
                0;
        final ranges = (res.headers.value('accept-ranges') ?? '')
            .toLowerCase()
            .contains('bytes');
        return ProbeResult.ok(
          res.realUri.toString(),
          size: size,
          ranges: ranges,
        );
      }
      if (code == 400 || code == 403 || code == 405 || code == 501) {
        // Sebagian server menolak HEAD atau request tanpa header browser;
        // coba GET dengan Range 0-0.
        return _probeRange(url, headers);
      }
      return ProbeResult.fail('HTTP $code');
    } on DioException catch (e) {
      return ProbeResult.fail(e.message ?? e.type.name);
    }
  }

  Future<ProbeResult> _probeRange(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            ..._browserHeaders,
            ...headers,
            'Accept': '*/*',
            'Range': 'bytes=0-0',
          },
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code != 200 && code != 206) {
        final body = (res.data ?? '').toLowerCase();
        if (body.contains('captcha_required') ||
            body.contains('rate_limited') ||
            body.contains('hotlink')) {
          return ProbeResult.fail('rate_limited');
        }
        return ProbeResult.fail('HTTP $code');
      }
      final contentRange = res.headers.value('content-range') ?? '';
      var size = 0;
      final slash = contentRange.lastIndexOf('/');
      if (slash >= 0) size = int.tryParse(contentRange.substring(slash + 1)) ?? 0;
      if (size == 0) {
        size = int.tryParse(
                res.headers.value(Headers.contentLengthHeader) ?? '') ??
            0;
      }
      return ProbeResult.ok(
        res.realUri.toString(),
        size: size,
        ranges: contentRange.isNotEmpty,
      );
    } on DioException catch (e) {
      return ProbeResult.fail(e.message ?? e.type.name);
    }
  }

  DownloadTask? _byId(String taskId) {
    for (final t in tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  void _notify() {
    if (_disposed) return;
    _syncService();
    notifyListeners();
  }

  /// Foreground service: hidup selama ada transfer, mati saat semua selesai.
  void _syncService() {
    final active = tasks.where((t) => t.isActive).toList();
    TransferSession.setDownloadsActive(active.isNotEmpty);
    if (active.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastServiceUpdate).inMilliseconds < 1500) return;
    _lastServiceUpdate = now;

    final first = active.first;
    final text = active.length == 1
        ? '${first.name} · ${(first.progress * 100).round()}%'
        : '${active.length} file · ${(first.progress * 100).round()}%';
    NativeDownloads.updateTransferService(text);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in tasks) {
      if (t.isActive) t.cancelToken?.cancel('dispose');
    }
    super.dispose();
  }
}
