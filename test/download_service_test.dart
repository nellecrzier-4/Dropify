import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropify/models/pd_item.dart';
import 'package:dropify/services/download_service.dart';
import 'package:dropify/services/pixeldrain_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.nel.dropify/native');

/// Adapter palsu: menyajikan byte sintetis dan mendukung Range.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.total, this.truncateFirst = false});

  final int total;
  final bool truncateFirst;
  int calls = 0;
  final List<String?> requestedRanges = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final rangeHeader = options.headers['Range'] as String?;
    requestedRanges.add(rangeHeader);

    var start = 0;
    var status = 200;
    if (rangeHeader != null) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) start = int.parse(match.group(1)!);
      status = 206;
    }

    var end = total;
    var claimedLength = total - start;
    if (status == 206) claimedLength = end - start;
    if (calls == 0 && truncateFirst) {
      end = start + (total - start) ~/ 2;
      claimedLength = total - start;
    }
    calls++;

    final length = end - start;
    final data = Uint8List(length);
    for (var i = 0; i < length; i++) {
      data[i] = (start + i) % 256;
    }

    return ResponseBody.fromBytes(
      data,
      status,
      headers: {
        Headers.contentLengthHeader: ['$claimedLength'],
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<Object?, Object?>> notifications;
  late bool storageGranted;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifications = [];
    storageGranted = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'hasAllFilesAccess':
          return storageGranted;
        case 'requestAllFilesAccess':
          return storageGranted;
        case 'notifyDownload':
          notifications.add(call.arguments as Map<Object?, Object?>);
          return true;
        case 'cancelNotification':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  const item = PdItem(id: 'QJ9MzyPM', name: 'file.bin', size: 64 * 1024);

  Future<DownloadService> makeService(
    _FakeAdapter adapter,
    Directory dir, {
    bool parallel = true,
  }) async {
    final dio = Dio()..httpClientAdapter = adapter;
    return DownloadService(
      PixeldrainApi(),
      dio: dio,
      folderOverride: dir.path,
      parallelMinSize: parallel ? 8 * 1024 : 1024 * 1024 * 1024,
      minSegmentSize: 4 * 1024,
      probe: (url, headers) async => ProbeResult.ok(
        url,
        size: adapter.total,
        ranges: true,
      ),
    );
  }

  Future<void> waitDone(DownloadTask task) async {
    for (var i = 0; i < 100; i++) {
      if (!task.isActive) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('mengunduh penuh dan menyimpan ke folder tujuan', () async {
    final dir = await Directory.systemTemp.createTemp('dropify_dl');
    final service = await makeService(_FakeAdapter(total: 64 * 1024), dir);

    final task = await service.download(item);
    await waitDone(task!);

    expect(task.status, DownloadStatus.done, reason: task.error ?? '');
    final file = File(task.path!);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 64 * 1024);
    expect(task.viaBypass, isTrue);
    expect(notifications.last['done'], isTrue);

    service.dispose();
    await dir.delete(recursive: true);
  });

  test('koneksi putus -> lanjut dari byte terakhir, bukan dari nol', () async {
    final dir = await Directory.systemTemp.createTemp('dropify_dl');
    final adapter = _FakeAdapter(total: 64 * 1024, truncateFirst: true);
    final service = await makeService(adapter, dir, parallel: false);

    final task = await service.download(item);
    await waitDone(task!);

    expect(task.status, DownloadStatus.done, reason: task.error ?? '');
    expect(await File(task.path!).length(), 64 * 1024);
    expect(adapter.requestedRanges.first, isNull);
    expect(adapter.requestedRanges.length, greaterThan(1));
    expect(adapter.requestedRanges.last, contains('bytes='));
    expect(task.attempts, greaterThan(1));

    service.dispose();
    await dir.delete(recursive: true);
  });

  test('file besar diunduh paralel dengan beberapa Range', () async {
    final dir = await Directory.systemTemp.createTemp('dropify_dl');
    final adapter = _FakeAdapter(total: 64 * 1024);
    final service = await makeService(adapter, dir);

    final task = await service.download(item);
    await waitDone(task!);

    expect(task.status, DownloadStatus.done, reason: task.error ?? '');
    expect(await File(task.path!).length(), 64 * 1024);
    final ranges = adapter.requestedRanges.whereType<String>().toList();
    expect(ranges.length, greaterThanOrEqualTo(4),
        reason: 'harus ada beberapa permintaan Range paralel');
    final bytes = await File(task.path!).readAsBytes();
    expect(bytes[0], 0);
    expect(bytes[32 * 1024], (32 * 1024) % 256);

    service.dispose();
    await dir.delete(recursive: true);
  });

  test('tanpa izin akses file -> error jelas, tidak mengunduh', () async {
    storageGranted = false;
    final dir = await Directory.systemTemp.createTemp('dropify_dl');
    final service = await makeService(_FakeAdapter(total: 1024), dir);

    final task = await service.download(item);
    expect(task, isNotNull);
    expect(task!.status, DownloadStatus.error);
    expect(task.error, 'storage_permission');
    expect(dir.listSync(), isEmpty);

    service.dispose();
    await dir.delete(recursive: true);
  });

  test('bypass ditolak -> pakai link Pixeldrain', () async {
    final dir = await Directory.systemTemp.createTemp('dropify_dl');
    final adapter = _FakeAdapter(total: 2048);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = DownloadService(
      PixeldrainApi(),
      dio: dio,
      folderOverride: dir.path,
      probe: (url, headers) async => url.contains('pixeldrain.eu.cc')
          ? const ProbeResult.fail('HTTP 403')
          : ProbeResult.ok(url, size: 2048, ranges: true),
    );

    final task = await service.download(item);
    await waitDone(task!);

    expect(task.viaBypass, isFalse);
    expect(task.status, DownloadStatus.done, reason: task.error ?? '');
    expect(await File(task.path!).length(), 2048);

    service.dispose();
    await dir.delete(recursive: true);
  });
}
