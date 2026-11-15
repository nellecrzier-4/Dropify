import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

/// Klien Filebin (https://filebin.net) — berbagi berkas sementara tanpa akun.
///
/// Satu "bin" berlaku seperti folder: berkas diunggah ke dalamnya, isinya bisa
/// dilihat, dan tautannya bisa dibagikan. Berkas dihapus otomatis 6 hari
/// setelah unggahan terakhir.
class FilebinApi {
  FilebinApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: base,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(minutes: 2),
                sendTimeout: null,
                validateStatus: (_) => true,
              ),
            );

  static const String base = 'https://filebin.net';
  static const String _alphabet = 'abcdefghijkmnopqrstuvwxyz23456789';

  final Dio _dio;

  /// Nama bin acak yang mudah dibaca, mis. `dropify-k3m9pq2x`.
  static String randomBin() {
    final rnd = Random.secure();
    final tail = List.generate(8, (_) => _alphabet[rnd.nextInt(_alphabet.length)])
        .join();
    return 'dropify-$tail';
  }

  static String downloadUrl(String bin, String name) =>
      '$base/$bin/${Uri.encodeComponent(name)}';

  static String binUrl(String bin) => '$base/$bin';

  /// Isi bin (folder).
  Future<FilebinBin> bin(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/${Uri.encodeComponent(id)}',
      options: Options(headers: const {'Accept': 'application/json'}),
    );
    final data = res.data;
    if (res.statusCode == 404 || data == null) {
      throw FilebinException('not_found');
    }
    return FilebinBin.fromJson(data);
  }

  /// Unggah satu berkas ke bin. [onProgress] menerima byte terkirim/total.
  Future<void> upload({
    required String bin,
    required File file,
    required String name,
    void Function(int sent, int total)? onProgress,
  }) async {
    final size = await file.length();
    final res = await _dio.post<Map<String, dynamic>>(
      '/',
      data: file.openRead(),
      options: Options(
        headers: {
          'bin': bin,
          'filename': name,
          'content-type': 'application/octet-stream',
          'content-length': size,
        },
        sendTimeout: null,
        receiveTimeout: const Duration(minutes: 5),
      ),
      onSendProgress: onProgress,
    );
    final code = res.statusCode ?? 0;
    if (code != 200 && code != 201 && code != 204) {
      final body = res.data;
      final message = body?['message']?.toString() ?? 'HTTP $code';
      throw FilebinException(message);
    }
  }

  Future<void> deleteFile(String bin, String name) async {
    await _dio.delete<void>(
      '/${Uri.encodeComponent(bin)}/${Uri.encodeComponent(name)}',
      options: Options(headers: const {'Accept': 'application/json'}),
    );
  }
}

class FilebinFile {
  const FilebinFile({
    required this.name,
    required this.bytes,
    this.contentType = '',
  });

  final String name;
  final int bytes;
  final String contentType;

  factory FilebinFile.fromJson(Map<String, dynamic> json) => FilebinFile(
        name: (json['filename'] ?? 'file').toString(),
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        contentType: (json['content-type'] ?? '').toString(),
      );
}

class FilebinBin {
  const FilebinBin({
    required this.id,
    required this.files,
    required this.bytes,
    this.expires,
  });

  final String id;
  final List<FilebinFile> files;
  final int bytes;
  final DateTime? expires;

  factory FilebinBin.fromJson(Map<String, dynamic> json) {
    final bin = json['bin'];
    final rawFiles = json['files'];
    return FilebinBin(
      id: (bin is Map ? bin['id'] : null)?.toString() ?? '',
      bytes: (bin is Map ? (bin['bytes'] as num?)?.toInt() : null) ?? 0,
      expires: bin is Map
          ? DateTime.tryParse((bin['expired_at'] ?? '').toString())?.toLocal()
          : null,
      files: rawFiles is List
          ? rawFiles
              .whereType<Map>()
              .map((e) => FilebinFile.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class FilebinException implements Exception {
  FilebinException(this.code);
  final String code;

  @override
  String toString() => code;
}
