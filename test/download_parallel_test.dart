// Memastikan unduhan paralel menulis tiap potongan pada offset yang benar
// (bug lama: file dibuka mode append sehingga offset diabaikan OS).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dropify/models/pd_item.dart';
import 'package:dropify/services/download_service.dart';
import 'package:dropify/services/pixeldrain_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nel.dropify/native');

  setUp(() async {
    // flutter_test memasang HttpClient tiruan yang membalas 400; matikan agar
    // request ke server lokal di test ini benar-benar terjadi.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
  });

  test('unduhan paralel menulis byte pada offset yang benar', () async {
    const size = 3 * 1024 * 1024 + 4321;
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = i % 251;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final range = request.headers.value('range');
      var start = 0;
      var end = size - 1;
      if (range != null) {
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range);
        if (match != null) {
          start = int.parse(match.group(1)!);
          end = int.parse(match.group(2)!);
        }
      }
      final response = request.response;
      response.statusCode = range != null ? 206 : 200;
      response.headers.set('content-range', 'bytes $start-$end/$size');
      response.headers.contentLength = end - start + 1;
      response.add(data.sublist(start, end + 1));
      await response.close();
    });

    final dir = await Directory.systemTemp.createTemp('dropify_parallel');
    final service = DownloadService(
      PixeldrainApi(),
      probe: (url, headers) async => ProbeResult.ok(
        'http://127.0.0.1:${server.port}/file',
        size: size,
        ranges: true,
      ),
      folderOverride: dir.path,
      parallelMinSize: 1,
      minSegmentSize: 1024 * 1024,
    );

    final task = await service.download(
      PdItem(id: 'abc123', name: 'big.bin', size: size),
    );

    expect(task, isNotNull);
    expect(task!.status, DownloadStatus.done, reason: task.error);

    final bytes = await File(task.path!).readAsBytes();
    expect(bytes.length, size);

    // Checksum sederhana: cukup untuk mendeteksi potongan yang tertukar.
    var checksum = 0;
    var expected = 0;
    for (var i = 0; i < size; i++) {
      checksum = (checksum + bytes[i] * ((i % 97) + 1)) % 1000000007;
      expected = (expected + data[i] * ((i % 97) + 1)) % 1000000007;
    }
    expect(checksum, expected);

    await server.close(force: true);
    await dir.delete(recursive: true);
    service.dispose();
  }, timeout: const Timeout(Duration(seconds: 45)));
}
