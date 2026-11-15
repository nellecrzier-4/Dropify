import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../utils/file_types.dart';
import 'app_settings.dart';
import 'proxy_service.dart';
import 'diagnostics.dart';
import 'transfer_session.dart';
import 'native_downloads.dart';
import 'pixeldrain_api.dart';
import 'pd_session.dart';
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
    this.extraHeaders = const {},
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

  /// Header tambahan untuk URL di luar Pixeldrain (mis. Cookie sesi WebView
  /// Gofile). Selalu ikut dikirim, termasuk saat [urlOverride] dipakai.
  final Map<String, String> extraHeaders;

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

  /// true kalau unduhan dipegang DownloadManager Android, bukan proses aplikasi.
  bool viaSystem = false;

  /// Id DownloadManager (untuk melanjutkan pemantauan setelah aplikasi dibuka
  /// lagi). Null kalau unduhan ditangani proses aplikasi.
  int? dmId;
  bool viaBypass = false;
  String? bypassError;
  int attempts = 0;

  CancelToken? cancelToken;
  bool canceled = false;
  bool waiting = false;

  /// Berapa kali server memaksa unduhan diulang dari byte 0.
  int fullRestarts = 0;



  DateTime? startedAt;
  DateTime? endedAt;

  DateTime _lastTick = DateTime.now();
  DateTime _lastChannelTick = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_Sample> _samples = <_Sample>[];

  /// Catat posisi byte pada suatu waktu. Kecepatan dihitung dari jendela
  /// 5 detik terakhir, jadi angkanya tidak melompat-lompat.
  void sampleSpeed(int bytes) {
    final now = DateTime.now();
    _samples.add(_Sample(now, bytes));
    while (_samples.length > 2 &&
        now.difference(_samples.first.at).inMilliseconds > 5000) {
      _samples.removeAt(0);
    }
    if (_samples.length < 2) return;
    final first = _samples.first;
    final last = _samples.last;
    final seconds = last.at.difference(first.at).inMilliseconds / 1000;
    if (seconds < 0.5) return;
    final delta = last.bytes - first.bytes;
    final instant = delta <= 0 ? 0.0 : delta / seconds;
    speed = speed <= 0 ? instant : speed * 0.4 + instant * 0.6;
  }

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

class _Sample {
  const _Sample(this.at, this.bytes);
  final DateTime at;
  final int bytes;
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
  'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
  'Sec-Fetch-Dest': 'empty',
  'Sec-Fetch-Mode': 'cors',
  'Sec-Fetch-Site': 'same-site',
};

/// Header permintaan yang menyerupai browser yang membuka halaman berkas itu
/// sendiri: proteksi hotlink Pixeldrain menolak referer yang tidak wajar,
/// jadi Referer/Origin diarahkan ke halaman berkasnya.
/// Varian Referer yang dicoba berurutan saat server menolak (403):
/// halaman berkas, domain host itu sendiri, lalu tanpa Referer sama sekali.
List<Map<String, String>> _headerVariants(String url) {
  final base = _pageHeaders(url);
  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  final own = host.isEmpty ? null : 'https://$host/';
  final session = PdSession.instance.cookie;
  Map<String, String> withSession(Map<String, String> value) => session == null
      ? value
      : {...value, 'Cookie': session};
  return [
    withSession(base),
    withSession({
      ...base,
      if (own != null) 'Referer': own,
      'Origin': 'https://$host',
    }),
    withSession({
      for (final e in base.entries)
        if (e.key != 'Referer' && !e.key.startsWith('Origin')) e.key: e.value,
    }),
  ];
}

Map<String, String> _pageHeaders(String url) {
  final id = _fileIdFromUrl(url);
  final referer =
      id != null ? 'https://pixeldrain.com/u/$id' : 'https://pixeldrain.com/';
  return {
    ..._browserHeaders,
    'Referer': referer,
    'Origin': 'https://pixeldrain.com',
  };
}

/// Id berkas dari URL API (`/api/file/<id>?download`) atau halaman `/u/<id>`.
String? _fileIdFromUrl(String url) => fileIdFromUrl(url);

/// Id berkas dari URL API (`/api/file/<id>`) atau halaman (`/u/<id>`).
String? fileIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final parts = uri.pathSegments;
  if (parts.contains('filesystem')) return null;
  for (final key in const ['u', 'file']) {
    final i = parts.indexOf(key);
    if (i >= 0 && parts.length > i + 1) return parts[i + 1];
  }
  return null;
}

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
    bool useSystemDownloader = true,
  })  : _probeOverride = probe,
        _useSystemDownloader = useSystemDownloader,
        _folderOverride = folderOverride,
        _parallelMinSize = parallelMinSize,
        _minSegmentSize = minSegmentSize,
        _dio = dio ?? _buildDio();

  /// Dio bawaan: memakai proxy pengguna kalau diaktifkan di Settings.
  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: null,
        followRedirects: true,
        maxRedirects: 6,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => ProxyService.instance.createHttpClient(),
    );
    return dio;
  }

  final PixeldrainApi api;
  final ProbeFn? _probeOverride;

  /// Unduhan dari URL luar (Gofile/WebView) diserahkan ke DownloadManager
  /// Android: berjalan di luar proses aplikasi, tahan aplikasi ditutup, dan
  /// tidak menulis ulang berkas besar lewat lapisan FUSE.
  final bool _useSystemDownloader;
  final String? _folderOverride;
  final Dio _dio;

  // Folder log mengikuti folder unduhan (test memakai folder sementara).

  /// Instance yang dipakai layar utama (pill HomeTab + sheet Transfers).
  /// Diisi oleh [DriveController] supaya unduhan yang dimulai dari layar lain
  /// (mis. WebView Gofile) muncul di tempat yang sama.
  static DownloadService? shared;

  static const String _resumeKey = 'dl_resume_v1';

  final List<DownloadTask> tasks = <DownloadTask>[];

  int _seq = 0;
  bool _disposed = false;
  DateTime _lastServiceUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastResumeSave = DateTime.fromMillisecondsSinceEpoch(0);

  int get activeCount => tasks.where((t) => t.isActive).length;
  bool get hasActive => activeCount > 0;

  String get folderPath => _folderOverride ?? NativeDownloads.folderPath;

  Future<DownloadTask?> download(
    PdItem item, {
    String? urlOverride,
    Map<String, String> headers = const {},
  }) async {
    if (item.isDir) return null;

    final fileId = (item.id ?? '').trim();
    // Unduhan dari URL luar (Gofile/WebView) tidak punya id Pixeldrain: kuncinya
    // URL itu sendiri, supaya dua berkas berbeda tidak saling menimpa.
    final key = urlOverride != null
        ? 'url:$urlOverride'
        : (fileId.isNotEmpty ? 'id:$fileId' : 'fs:${item.fsPath.join('/')}');
    for (final t in tasks) {
      if (t.key == key && t.isActive) return t;
      // Halaman Gofile bisa memicu tautan baru untuk berkas yang sama; jangan
      // sampai satu berkas berjalan sebagai beberapa unduhan sekaligus.
      if (urlOverride != null && t.isActive && t.name == item.name) return t;
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
      extraHeaders: headers,
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

    if (_useSystemDownloader) {
      // Semua unduhan diserahkan ke DownloadManager Android: berjalan di proses
      // sistem, lanjut walau aplikasi ditutup, dan bisa dipantau ulang setelah
      // aplikasi dibuka kembali.
      final url = urlOverride ?? task.directUrl;
      final merged = <String, String>{...task.directHeaders, ...headers};
      if (headers.isNotEmpty) {
        // Header sesi (cookie) menang atas header API.
        merged.addAll(headers);
      }
      if (await _runSystemDownload(task, url, merged)) return task;
      _log('native', '${task.name}: DownloadManager tidak tersedia');

      if (urlOverride != null) {
        if (await _runNativeDownload(task, urlOverride, headers)) return task;
        task
          ..status = DownloadStatus.error
          ..error = _s.downloaderUnavailable
          ..endedAt = DateTime.now();
        _notify();
        return task;
      }
    }

    await _resolveAndRun(task);
    return task;
  }

  /// Serahkan unduhan ke DownloadManager Android lalu pantau progresnya.
  ///
  /// Mengembalikan false hanya kalau enqueue gagal total (mis. kanal native
  /// tidak ada), supaya pemanggil bisa memakai downloader di dalam app.
  /// Serahkan unduhan ke DownloadManager Android (proses sistem).
  ///
  /// Ini isolasi terkuat: berkas ditulis oleh sistem, bukan proses aplikasi,
  /// jadi unduhan tetap berjalan walau Dropify ditutup dan memori aplikasi
  /// tidak tersentuh. Mengembalikan false hanya kalau enqueue ditolak.
  Future<bool> _runSystemDownload(
    DownloadTask task,
    String url,
    Map<String, String> headers,
  ) async {
    NativeDownloadHandle handle;
    try {
      handle = await NativeDownloads.enqueue(
        url: url,
        name: task.name,
        headers: headers,
      );
    } catch (e) {
      _log('native', '${task.name}: enqueue gagal ($e)');
      return false;
    }

    task
      ..status = DownloadStatus.downloading
      ..viaSystem = true
      ..dmId = handle.id
      ..path = handle.path
      ..startedAt = DateTime.now()
      ..url = url;
    _log('native', '${task.name}: DownloadManager #${handle.id}');
    _notify();
    return _pollSystemDownload(task, handle.id);
  }

  /// Pantau tugas DownloadManager sampai selesai/gagal.
  Future<bool> _pollSystemDownload(DownloadTask task, int dmId) async {
    var missing = 0;

    while (!_disposed) {
      if (task.canceled) {
        await NativeDownloads.cancel(dmId);
        return true;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      final state = await NativeDownloads.query(dmId);
      if (state == null) {
        if (++missing >= 3) {
          task
            ..status = DownloadStatus.error
            ..error = _s.downloaderUnavailable
            ..endedAt = DateTime.now();
          _notify();
          return true;
        }
        continue;
      }
      missing = 0;

      if (state.total > 0) task.size = state.total;
      task.received = state.received;
      task.sampleSpeed(state.received);
      _notify();

      if (state.isDone) {
        task
          ..status = DownloadStatus.done
          ..received = task.size > 0 ? task.size : state.received
          ..speed = 0
          ..endedAt = DateTime.now();
        _log('native', '${task.name}: selesai ${task.received} byte');
        DownloadHistory.instance.add(
          DownloadRecord(
            name: task.name,
            path: task.path ?? '',
            size: task.received,
            time: DateTime.now(),
          ),
        );
        NativeDownloads.notifyDownload(
          id: task.notifyId,
          title: task.name,
          text: formatSize(task.received),
          progress: 1,
          done: true,
        );
        _notify();
        return true;
      }
      if (state.isFailed) {
        task
          ..status = DownloadStatus.error
          ..error = state.error ?? _s.downloadFailed
          ..speed = 0
          ..endedAt = DateTime.now();
        _log('native', '${task.name}: gagal ${task.error}');
        _notify();
        return true;
      }
    }
    return true;
  }

  /// Unduhan URL luar dijalankan sepenuhnya oleh kode native
  /// ([FileDownloader]) — Dart hanya menerima kejadian progres. Dengan begitu
  /// memori aplikasi tidak tumbuh mengikuti ukuran berkas, dan WebView tidak
  /// ikut menahan unduhan.
  Future<bool> _runNativeDownload(
    DownloadTask task,
    String url,
    Map<String, String> headers,
  ) async {
    final done = Completer<bool>();
    final startedAt = DateTime.now();
    var lastReceived = 0;
    var lastCheck = startedAt;

    NativeDownloads.onNativeProgress = (event) {
      if (event['id']?.toString() != task.id) return;
      final state = event['state']?.toString() ?? '';
      final received = (event['received'] as num?)?.toInt() ?? 0;
      final total = (event['total'] as num?)?.toInt() ?? 0;

      if (total > 0) task.size = total;
      task.received = received;
      final now = DateTime.now();
      final seconds = now.difference(lastCheck).inMilliseconds / 1000;
      if (seconds >= 0.5) {
        final delta = received - lastReceived;
        task.speed = delta <= 0 ? 0 : delta / seconds;
        lastReceived = received;
        lastCheck = now;
      }
      _notifyUi();

      if (state == 'done') {
        task
          ..status = DownloadStatus.done
          ..received = total > 0 ? total : received
          ..size = total > 0 ? total : received
          ..path = event['path']?.toString() ?? task.path
          ..speed = 0
          ..endedAt = DateTime.now();
        _log('native', '${task.name}: selesai ${task.received} byte');
        DownloadHistory.instance.add(
          DownloadRecord(
            name: task.name,
            path: task.path ?? '',
            size: task.received,
            time: DateTime.now(),
          ),
        );
        NativeDownloads.notifyDownload(
          id: task.notifyId,
          title: task.name,
          text: formatSize(task.size),
          progress: 1,
          done: true,
        );
        _notifyUi();
        if (!done.isCompleted) done.complete(true);
      } else if (state == 'failed') {
        task
          ..status = DownloadStatus.error
          ..error = event['error']?.toString() ?? _s.downloadFailed
          ..speed = 0
          ..endedAt = DateTime.now();
        _log('native', '${task.name}: gagal ${task.error}');
        NativeDownloads.notifyDownload(
          id: task.notifyId,
          title: task.name,
          text: '',
          progress: 0,
          error: task.error,
        );
        _notifyUi();
        if (!done.isCompleted) done.complete(true);
      }
    };

    final started = await NativeDownloads.startNativeDownload(
      id: task.id,
      url: url,
      name: task.name,
      headers: headers,
    );
    if (!started) {
      NativeDownloads.onNativeProgress = null;
      _log('native', '${task.name}: downloader native menolak');
      return false;
    }

    task
      ..status = DownloadStatus.downloading
      ..viaSystem = true
      ..startedAt = startedAt
      ..url = url;
    _log('native', '${task.name}: native ${_short(url)}');
    _notify();

    while (!done.isCompleted && !_disposed) {
      if (task.canceled) {
        await NativeDownloads.cancelNativeDownload(task.id);
        if (!done.isCompleted) done.complete(true);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    NativeDownloads.onNativeProgress = null;
    return true;
  }

  /// Simpan keadaan tugas yang belum selesai ke SharedPreferences.
  ///
  /// Kalau aplikasi dihentikan sistem di tengah unduhan 10 GB, saat dibuka
  /// lagi tugasnya dibuat ulang dan melanjutkan dari byte terakhir.
  Future<void> _saveResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <Map<String, dynamic>>[
        for (final t in tasks)
          if (t.isActive && t.size > 0)
            {
              'key': t.key,
              'name': t.name,
              'url': t.urlOverride ?? t.url,
              'size': t.size,
              'received': t.received,
              'headers': t.extraHeaders,
              'dmId': t.dmId,
            },
      ];
      if (data.isEmpty) {
        await prefs.remove(_resumeKey);
      } else {
        await prefs.setString(_resumeKey, jsonEncode(data));
      }
    } catch (_) {
      // Penyimpanan status tidak boleh mengganggu unduhan.
    }
  }

  /// Buat ulang tugas yang terputus saat aplikasi ditutup, lalu lanjutkan.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_resumeKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      final resumed = <DownloadTask>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final url = entry['url']?.toString() ?? '';
        final key = entry['key']?.toString() ?? '';
        if (url.isEmpty || key.isEmpty) continue;
        if (tasks.any((t) => t.key == key && t.isActive)) continue;
        final name = entry['name']?.toString() ?? 'file';
        final headers = <String, String>{};
        final rawHeaders = entry['headers'];
        if (rawHeaders is Map) {
          rawHeaders.forEach((k, v) {
            headers['$k'] = '$v';
          });
        }
        final task = DownloadTask(
          id: 'dl${DateTime.now().microsecondsSinceEpoch}_${_seq}',
          key: key,
          item: PdItem(name: name, size: 0),
          name: name,
          directUrl: url,
          directHeaders: api.authHeaders,
          notifyId: 4200 + _seq++,
          urlOverride: url,
          extraHeaders: headers,
        )
          ..size = (entry['size'] as num?)?.toInt() ?? 0
          ..dmId = (entry['dmId'] as num?)?.toInt();
        tasks.insert(0, task);
        resumed.add(task);
      }
      await prefs.remove(_resumeKey);
      if (resumed.isEmpty) return;
      _log('resume', '${resumed.length} unduhan dilanjutkan');
      _notify();
      for (final task in resumed) {
        unawaited(_resumeTask(task));
      }
    } catch (e) {
      _log('resume', 'gagal: $e');
    }
  }

  Future<void> _resumeTask(DownloadTask task) async {
    final dmId = task.dmId;
    if (dmId != null) {
      // Unduhan sistem masih berjalan: cukup sambungkan kembali pemantauannya.
      _log('resume', '${task.name}: sambung DownloadManager #$dmId');
      task
        ..status = DownloadStatus.downloading
        ..viaSystem = true;
      _notify();
      await _pollSystemDownload(task, dmId);
      return;
    }
    if (!await _ensureStorage()) {
      _fail(task, 'storage_permission');
      return;
    }
    final url = task.urlOverride;
    if (url != null) {
      await _runNativeDownload(task, url, task.extraHeaders);
      return;
    }
    await _resolveAndRun(task);
  }

  /// Perbarui UI saja. DownloadManager punya notifikasi sendiri, jadi
  /// foreground service aplikasi tidak perlu dinyalakan lagi.
  void _notifyUi() {
    if (_disposed) return;
    notifyListeners();
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
      ..fullRestarts = 0
      ..startedAt = null
      ..endedAt = null;
  }

  Future<void> _resolveAndRun(DownloadTask task) async {
    if (_disposed || task.canceled) return;

    final override = task.urlOverride;
    if (override != null) {
      _log('probe', '${task.name} <- ${_short(override)}');
      final probe = await _probeUrl(override, task.extraHeaders);
      if (_disposed || task.canceled) return;
      _log('probe', '${task.name}: ok=${probe.ok} size=${probe.size} '
          'ranges=${probe.ranges} error=${probe.error}');
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
        ..error = 'Link: ${probe.error ?? _s.probeUnreachable}'
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
      task.bypassError = last?.error ?? _s.probeFailed;
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

    var directProbe = await _probeUrl(task.directUrl, task.directHeaders);
    // Kalau ditolak karena kuota/IP, putar proxy lalu coba lagi.
    var probeRotations = 0;
    while (!directProbe.ok &&
        probeRotations < 4 &&
        (directProbe.error == 'rate_limited' || task.viaBypass)) {
      if (!ProxyService.instance.rotate()) break;
      probeRotations++;
      _log('proxy', 'putar ke ${ProxyService.instance.current} '
          '(probe ${directProbe.error})');
      directProbe = await _probeUrl(task.directUrl, task.directHeaders);
      if (_disposed || task.canceled) return;
    }
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

    final directError = directProbe.error ?? _s.probeFailed;
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

    // Cek ruang: menulis berkas 11 GB di penyimpanan penuh membuat aplikasi
    // lain ikut berhenti. Lebih baik berhenti dengan pesan jelas.
    if (knownSize > 0) {
      final free = await NativeDownloads.freeSpace();
      if (free > 0 && free < knownSize + 512 * 1024 * 1024) {
        _log('space', '${task.name}: butuh $knownSize, sisa $free');
        _fail(task, 'storage_full');
        return;
      }
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

      _log('done', '${task.name}: ${task.size} byte -> ${target.path}');
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
    _log('fail', '${task.name}: $message');
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
      error: message == 'storage_permission'
          ? _s.fileAccessRequired
          : (message == 'storage_full' ? _s.storageFull : message),
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
        final text = e.toString();
        if (text.contains('429') ||
            text.contains('403') ||
            text.contains('limit_page') ||
            text.contains('captcha_required')) {
          if (ProxyService.instance.rotate()) {
            _log('proxy', 'putar ke ${ProxyService.instance.current} (unduhan)');
          }
        }
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
      // CATATAN: jangan pra-alokasi berkas (setPosition(size-1) + writeByte).
      // Di /storage/emulated/0 (FUSE) itu memicu penulisan nol sebesar seluruh
      // berkas — untuk 11 GB perangkat sibuk bermenit-menit, progres terlihat
      // macet, lalu aplikasi dihentikan sistem. Setiap potongan menulis pada
      // offset eksplisit, jadi berkas memanjang sendiri sampai ukuran penuh.

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
        throw _RetryableError(_s.connectionDropped);
      }

      await raf.flush();
      final length = await raf.length();
      if (length != size) {
        throw _RetryableError(_s.sizeMismatch(length, size));
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
              ..._pageHeaders(url),
              'Accept': '*/*',
              'Range': 'bytes=$from-${chunk.end}',
              ...task.extraHeaders,
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
          throw _RetryableError(_s.chunkIncomplete);
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
    // Berkas raksasa: satu koneksi saja. Puluhan koneksi paralel untuk berkas
    // 10 GB+ membuat memori dan I/O perangkat jenuh — aplikasi lalu dihentikan
    // sistem. Satu koneksi yang ditulis berurutan jauh lebih tahan lama.
    if (size >= 1024 * 1024 * 1024) return 1;
    if (size >= 256 * 1024 * 1024) return 2;
    if (size >= 64 * 1024 * 1024) return max.clamp(1, 4);
    if (size >= 32 * 1024 * 1024) return (max - 2).clamp(1, max);
    return (max - 4).clamp(1, max);
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

    final token = CancelToken();
    task.cancelToken = token;

    // Coba beberapa varian Referer: sebagian CDN menolak referer yang tidak
    // cocok dengan halaman berkas (proteksi hotlink).
    Response<ResponseBody>? response;
    var code = 0;
    String? bodyHint;
    for (final variant in _headerVariants(url)) {
      final headers = <String, String>{...variant, 'Accept': '*/*'};
      if (start > 0) headers['Range'] = 'bytes=$start-';
      headers.addAll(task.extraHeaders);
      if (!task.viaBypass) headers.addAll(task.directHeaders);

      response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          receiveTimeout: null,
        ),
        cancelToken: token,
      );
      code = response.statusCode ?? 0;
      _log('http', '${task.name}: $code start=$start '
          'referer=${variant['Referer'] ?? '-'}');
      if (code != 403) break;
      // Simpan petunjuk isi balasan sekali, supaya pesan errornya jelas.
      bodyHint ??= await _peekBody(response.data!);
    }
    response ??= await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        receiveTimeout: null,
      ),
      cancelToken: token,
    );
    if (code == 416) {
      try {
        await part.delete();
      } catch (_) {}
      throw _RetryableError(_s.invalidRange);
    }
    if (code == 200 || code == 206) {
      final type = (response.headers.value(Headers.contentTypeHeader) ?? '')
          .toLowerCase();
      if (type.contains('text/html')) {
        final hint = await _peekBody(response.data!);
        final lower = hint.toLowerCase();
        _log('limit', '${task.name}: halaman HTML (${hint.length} char)');
        if (lower.contains('limit') ||
            lower.contains('human') ||
            lower.contains('captcha')) {
          // Kuota harian per-IP: putar proxy lalu ulangi.
          throw _RetryableError(
            lower.contains('captcha') ? 'captcha_required' : 'limit_page',
          );
        }
        throw _RetryableError('HTML $hint');
      }
    }
    if (code != 200 && code != 206) {
      final captcha = bodyHint != null &&
          bodyHint.toLowerCase().contains('captcha');
      throw PixeldrainException(
        captcha
            ? 'captcha_required'
            : (code == 403 && (bodyHint?.isNotEmpty ?? false)
                ? 'HTTP 403 · $bodyHint'
                : 'HTTP $code'),
      );
    }

    final resuming = code == 206 && start > 0;
    if (!resuming) {
      if (start > 0) {
        // Server mengabaikan Range (balas 200): berkas harus diulang dari nol.
        // Dibatasi supaya tidak berputar-putar mengunduh ulang terus-menerus.
        task.fullRestarts++;
        _log('restart', '${task.name}: server mengabaikan Range, mulai dari 0 '
            '(percobaan ${task.fullRestarts})');
        if (task.fullRestarts > 3) {
          throw _RetryableError(_s.downloadRestartLoop);
        }
      }
      start = 0;
    }

    final lengthHeader =
        int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
    task.size = lengthHeader != null ? lengthHeader + start : 0;
    task.received = start;

    // Tulis lewat RandomAccessFile dan TUNGGU setiap kali, bukan lewat IOSink
    // tanpa backpressure: kalau jaringan lebih cepat dari penyimpanan (FUSE),
    // IOSink menumpuk seluruh unduhan di memori sampai proses dibunuh sistem.
    final raf = await part.open(
      mode: resuming ? FileMode.append : FileMode.write,
    );

    var received = start;
    final pending = BytesBuilder(copy: false);
    Future<void> writePending() async {
      if (pending.length == 0) return;
      final bytes = pending.takeBytes();
      await raf.writeFrom(bytes);
    }

    try {
      await for (final chunk in response.data!.stream) {
        if (task.canceled) {
          throw _RetryableError('dibatalkan');
        }
        pending.add(chunk);
        received += chunk.length;
        if (pending.length >= 512 * 1024) await writePending();
        _reportProgress(task, received);
      }
      await writePending();
      await raf.flush();
    } finally {
      await raf.close();
    }

    if (task.size > 0 && received < task.size) {
      throw _RetryableError(_s.connectionDropped);
    }
    task.received = received;
  }

  void _reportProgress(DownloadTask task, int received) {
    task.received = received;
    final now = DateTime.now();
    final elapsed = now.difference(task._lastTick).inMilliseconds;
    if (elapsed >= 500) {
      task.sampleSpeed(received);
      if (task.speed > task.peakSpeed) task.peakSpeed = task.speed;
      task._lastTick = now;

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

  /// Baca maksimal 300 byte pertama balasan (untuk pesan error 403).
  Future<String> _peekBody(ResponseBody body) async {
    try {
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        bytes.addAll(chunk.take(300 - bytes.length));
        if (bytes.length >= 300) break;
      }
      final text = String.fromCharCodes(bytes).replaceAll(RegExp(r'\s+'), ' ').trim();
      return text.length > 160 ? text.substring(0, 160) : text;
    } catch (_) {
      return '';
    }
  }

  String _short(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final tail = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return '${uri.host}/…/$tail';
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

  /// Teks error sesuai bahasa aktif.
  AppStrings get _s => LocaleController.instance.strings;

  void _log(String tag, String message) {
    Diagnostics.instance.configure(folderPath);
    Diagnostics.instance.log('download/$tag', message);
  }

  String _friendlyError(Object? error) {
    if (error == null) return _s.downloadFailed;
    if (error is PixeldrainException) return error.message;
    if (error is FileSystemException) {
      final text = error.toString();
      if (text.contains('ENOSPC') || text.contains('No space left')) {
        return _s.storageFull;
      }
    }
    if (error is _RetryableError) return error.message;
    if (error is DioException) {
      final code = error.response?.statusCode ?? 0;
      if (code == 404) return _s.fileNotFoundOnPixeldrain;
      if (code == 403) return _s.downloadBlocked;
      if (code == 401) return _s.downloadDenied;
      if (code == 429) return _s.serverRateLimited;
      if (code >= 500) return _s.serverError(code);
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return _s.connectionTimeout;
        case DioExceptionType.connectionError:
          return _s.noInternet;
        default:
          return error.message ?? _s.downloadFailed;
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
          headers: {..._pageHeaders(url), ...headers, 'Accept': '*/*'},
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
      if (code == 429 || code == 403) {
        // 403 juga bisa berarti proteksi hotlink: coba sekali dengan header
        // halaman berkas sebelum memutar proxy.
        if (code == 403) {
          final retry = await _probeRange(url, headers);
          if (retry.ok) return retry;
        }
        if (ProxyService.instance.rotate()) {
          _log('proxy', 'putar ke ${ProxyService.instance.current} (HTTP $code)');
          return await _probeWithNetwork(url, headers);
        }
        return ProbeResult.fail(code == 429 ? 'rate_limited' : 'HTTP $code');
      }
      if (code == 400 || code == 405 || code == 501) {
        // Sebagian server menolak HEAD; coba GET dengan Range 0-0.
        return await _probeRange(url, headers);
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
            ..._pageHeaders(url),
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
        if (body.contains('captcha') ||
            body.contains('prove that you') ||
            body.contains('human')) {
          return ProbeResult.fail('captcha_required');
        }
        if (body.contains('rate_limited') ||
            body.contains('hotlink') ||
            body.contains('download limit') ||
            body.contains('limit exceeded')) {
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
    final now = DateTime.now();
    if (now.difference(_lastResumeSave).inSeconds >= 5) {
      _lastResumeSave = now;
      unawaited(_saveResume());
    }
  }

  /// Foreground service: hidup selama ada transfer, mati saat semua selesai.
  ///
  /// Unduhan yang dipegang DownloadManager berjalan di proses sistem, jadi
  /// tidak butuh foreground service kita — dan service dataSync yang terlalu
  /// lama hidup justru dimatikan sistem (ForegroundServiceDidNotStopInTime).
  void _syncService() {
    final active = tasks.where((t) => t.isActive).toList();
    final allSystem = active.isNotEmpty && active.every((t) => t.viaSystem);
    TransferSession.setDownloadsActive(active.isNotEmpty && !allSystem);
    if (active.isEmpty || allSystem) return;

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
