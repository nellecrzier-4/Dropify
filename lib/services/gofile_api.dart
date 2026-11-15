import 'dart:convert';

import 'package:dio/dio.dart';

/// Klien API Gofile (https://gofile.io/api).
///
/// Login memakai email: `POST /accounts` mengirim tautan masuk ke email itu,
/// lalu token dari tautan tersebut disimpan di perangkat. Token guest juga bisa
/// dipakai tanpa email.
class GofileApi {
  GofileApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.gofile.io',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  /// Minta tautan masuk dikirim ke [email].
  Future<void> requestLoginLink(String email) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/accounts',
      data: {'email': email},
    );
    if ((res.data?['status'] as String?) != 'ok') {
      throw GofileException(
        (res.data?['status'] as String?) ?? 'gagal_mengirim',
      );
    }
  }

  /// Ambil info akun dari token. Endpoint Gofile butuh account id di path,
  /// jadi id diambil dari klaim di dalam token (JWT) kalau ada.
  Future<GofileAccount> account(String token, {String? accountId}) async {
    final id = accountId ?? accountIdFromToken(token);
    if (id == null) throw GofileException('butuh_api_token');
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/accounts/$id',
        options: Options(headers: _auth(token)),
      );
      final data = _data(res);
      return GofileAccount.fromJson(data, fallbackToken: token);
    } on DioException catch (e) {
      throw GofileException(
        _apiCode(e) ?? 'HTTP ${e.response?.statusCode ?? 0}',
      );
    }
  }

  /// Baca account id dari payload JWT (token API dari halaman profil Gofile).
  static String? accountIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final json = utf8.decode(base64.decode(payload));
      final map = jsonDecode(json);
      if (map is! Map) return null;
      for (final key in const ['id', 'accountId', 'account', 'sub', 'aid']) {
        final value = map[key];
        if (value is String && value.length >= 8) return value;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _apiCode(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['status'] is String) {
      return data['status'] as String;
    }
    return null;
  }

  /// Daftar isi folder (root memakai `rootFolder` dari akun).
  Future<List<GofileEntry>> list(
    String folderId,
    String token,
  ) async {
    late final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>(
        '/contents/$folderId',
        queryParameters: {'token': token, 'pageSize': 1000},
      );
    } on DioException catch (e) {
      throw GofileException(
        _apiCode(e) ?? 'HTTP ${e.response?.statusCode ?? 0}',
      );
    }
    final data = _data(res);
    final children = data['children'];
    final entries = <GofileEntry>[];
    if (children is Map) {
      for (final value in children.values) {
        if (value is Map<String, dynamic>) {
          entries.add(GofileEntry.fromJson(value));
        } else if (value is Map) {
          entries.add(GofileEntry.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    entries.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return entries;
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) {
    final body = res.data;
    if (body == null || body['status'] != 'ok') {
      throw GofileException(
        (body?['status'] as String?) ?? 'HTTP ${res.statusCode}',
      );
    }
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Terima token mentah atau tautan masuk (…?token=… / …/auth/…).
  static String? tokenFromInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token'];
    }
    if (text.contains('/')) {
      final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments != null && segments.isNotEmpty) return segments.last;
    }
    if (text.length >= 20) return text;
    return null;
  }
}

class GofileException implements Exception {
  GofileException(this.code);

  final String code;

  @override
  String toString() => code;
}

class GofileAccount {
  const GofileAccount({
    required this.id,
    required this.email,
    required this.tier,
    required this.rootFolder,
    required this.token,
    this.storage = 0,
    this.fileCount = 0,
  });

  final String id;
  final String email;
  final String tier;
  final String rootFolder;
  final String token;
  final int storage;
  final int fileCount;

  bool get isGuest => tier == 'guest';

  factory GofileAccount.fromJson(
    Map<String, dynamic> json, {
    required String fallbackToken,
  }) {
    final stats = json['statsCurrent'];
    return GofileAccount(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      tier: (json['tier'] ?? 'guest').toString(),
      rootFolder: (json['rootFolder'] ?? '').toString(),
      token: (json['token'] ?? fallbackToken).toString(),
      storage: stats is Map ? (stats['storage'] as num?)?.toInt() ?? 0 : 0,
      fileCount: stats is Map ? (stats['fileCount'] as num?)?.toInt() ?? 0 : 0,
    );
  }
}

class GofileEntry {
  const GofileEntry({
    required this.id,
    required this.name,
    required this.isDir,
    required this.size,
    required this.date,
    this.link,
  });

  final String id;
  final String name;
  final bool isDir;
  final int size;
  final DateTime date;
  final String? link;

  factory GofileEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'file').toString();
    final time = (json['createTime'] as num?)?.toInt() ?? 0;
    return GofileEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? 'file').toString(),
      isDir: type == 'folder',
      size: (json['size'] as num?)?.toInt() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(time * 1000).toLocal(),
      link: json['link']?.toString(),
    );
  }
}
