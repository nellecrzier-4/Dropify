import 'dart:io';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dropify/models/pd_item.dart';
import 'package:dropify/services/download_service.dart';
import 'package:dropify/services/pixeldrain_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uji manual untuk berkas > 2 GB (bug lama: penulisan append membuat berkas
/// membengkak di atas 4 GB, dan offset tiap potongan diabaikan OS).
/// Jalankan dengan:
///
///   BIG=1 flutter test test/big_file_test.dart --timeout none
///
/// Normalnya dilewati supaya `flutter test` tetap cepat.
const int _size = 2300 * 1024 * 1024; // 2,3 GB

/// Sumber byte sintetis yang mendukung Range: byte ke-n = n % 256.
class _BigAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final range = options.headers['Range'] as String?;
    var start = 0;
    var end = _size - 1;
    var status = 200;
    if (range != null) {
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (match != null) {
        start = int.parse(match.group(1)!);
        final rawEnd = match.group(2) ?? '';
        if (rawEnd.isNotEmpty) end = math.min(int.parse(rawEnd), _size - 1);
        status = 206;
      }
    }

    Stream<Uint8List> body() async* {
      const piece = 256 * 1024;
      final buffer = Uint8List(piece);
      var cursor = start;
      while (cursor <= end) {
        final take = math.min(piece, end - cursor + 1);
        for (var i = 0; i < take; i++) {
          buffer[i] = (cursor + i) & 0xFF;
        }
        yield Uint8List.fromList(Uint8List.sublistView(buffer, 0, take));
        cursor += take;
      }
    }

    return ResponseBody(
      body(),
      status,
      headers: {
        Headers.contentLengthHeader: ['${end - start + 1}'],
        HttpHeaders.acceptRangesHeader: ['bytes'],
        if (status == 206)
          HttpHeaders.contentRangeHeader: ['bytes $start-$end/$_size'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enabled = Platform.environment['BIG'] == '1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nel.dropify/native'),
      (call) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nel.dropify/native'),
      null,
    );
  });

  test(
    'berkas 2,3 GB utuh: ukuran tepat dan byte di offset benar',
    () async {
      final dir = await Directory.systemTemp.createTemp('dropify_big');
      final adapter = _BigAdapter();
      final service = DownloadService(
        PixeldrainApi(),
        dio: Dio()..httpClientAdapter = adapter,
        folderOverride: dir.path,
        parallelMinSize: 16 * 1024 * 1024,
        minSegmentSize: 8 * 1024 * 1024,
        // Uji penulis berkas aplikasi, bukan DownloadManager.
        useSystemDownloader: false,
        probe: (url, headers) async =>
            ProbeResult.ok(url, size: _size, ranges: true),
      );

      final task = await service.download(
        const PdItem(name: 'raksasa.bin', size: 0),
        urlOverride:
            'https://store-eu-par-1.gofile.io/download/web/tok/raksasa.bin',
      );
      expect(task, isNotNull);
      final done = task!;
      service.dispose();

      expect(done.status, DownloadStatus.done, reason: done.error ?? '');
      expect(adapter.requests, greaterThan(1), reason: 'harus paralel');
      expect(done.size, _size);

      final file = File(done.path!);
      expect(await file.length(), _size, reason: 'ukuran harus tepat');

      final raf = await file.open();
      try {
        for (final offset in [
          0,
          1,
          4095,
          1 << 20,
          (2 * 1024 * 1024 * 1024) - 8,
          _size - 1,
        ]) {
          await raf.setPosition(offset);
          final byte = await raf.read(1);
          expect(byte.first, offset & 0xFF, reason: 'offset $offset');
        }
      } finally {
        await raf.close();
      }

      await dir.delete(recursive: true);
    },
    skip: enabled ? false : 'set BIG=1 untuk menguji berkas > 2 GB',
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
