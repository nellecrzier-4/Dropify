import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dropify/services/gofile_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapter palsu: melayani /servers lalu balasan unggah sukses.
class _FakeUploadAdapter implements HttpClientAdapter {
  _FakeUploadAdapter({this.fail = false});

  final bool fail;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.uri.toString());
    // Habiskan body permintaan supaya unggahan tidak menggantung.
    if (requestStream != null) {
      await requestStream.drain<void>();
    }

    if (options.uri.path == '/servers') {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'data': {
            'servers': [
              {'name': 'store5', 'zone': 'eu'},
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (fail) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'error-notPremium', 'data': <String, dynamic>{}}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'status': 'ok',
        'data': {
          'downloadPage': 'https://gofile.io/d/abc123',
          'id': 'file-id',
          'name': 'berkas.bin',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nativeCalls = <MethodCall>[];

  setUp(() {
    nativeCalls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nel.dropify/native'),
      (call) async {
        nativeCalls.add(call);
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nel.dropify/native'),
      null,
    );
  });

  Future<(GofileUploadService, File, Directory)> setup({
    bool fail = false,
  }) async {
    final dir = await Directory.systemTemp.createTemp('dropify_up');
    final file = File('${dir.path}/data.bin');
    await file.writeAsBytes(List<int>.generate(256 * 1024, (i) => i % 256));
    final dio = Dio()..httpClientAdapter = _FakeUploadAdapter(fail: fail);
    return (GofileUploadService(dio: dio), file, dir);
  }

  test('unggahan sukses menandai selesai dan menyimpan tautan', () async {
    final (service, file, dir) = await setup();
    final task = await service.upload(
      path: file.path,
      name: 'data.bin',
      token: 'token-uji',
      folderId: 'folder-akar',
    );

    expect(task.status, GofileUploadStatus.done, reason: task.error ?? '');
    expect(task.downloadPage, 'https://gofile.io/d/abc123');
    expect(task.progress, 1);
    expect(service.hasActive, isFalse);

    await dir.delete(recursive: true);
  });

  test('balasan error Gofile jadi status error yang terbaca', () async {
    final (service, file, dir) = await setup(fail: true);
    final task = await service.upload(
      path: file.path,
      name: 'data.bin',
      token: 'token-uji',
    );

    expect(task.status, GofileUploadStatus.error);
    expect(task.error, contains('error-notPremium'));

    await dir.delete(recursive: true);
  });
}
