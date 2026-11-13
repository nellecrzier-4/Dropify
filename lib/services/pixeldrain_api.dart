import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pd_item.dart';

class LoginResult {
  final bool success;
  final bool needsOtp;
  final String message;

  /// Kode error yang bisa diterjemahkan UI (lihat AppStrings.loginError).
  final String? code;

  const LoginResult({
    required this.success,
    this.needsOtp = false,
    this.message = '',
    this.code,
  });
}

class PixeldrainException implements Exception {
  final String message;
  final bool unauthorized;
  PixeldrainException(this.message, {this.unauthorized = false});

  @override
  String toString() => message;
}

class PixeldrainApi {
  static const _keyPref = 'pd_auth_key';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pixeldrain.com/api',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true,
    ),
  );

  String? _authKey;

  String? get authKey => _authKey;

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {};
  }

  void _applyKey(String key) {
    _authKey = key;
    _dio.options.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode(':$key'))}';
  }

  /// Memuat auth key yang tersimpan. Return true kalau ada.
  Future<bool> loadSavedKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref);
    if (key == null || key.isEmpty) return false;
    _applyKey(key);
    return true;
  }

  Future<LoginResult> login(
    String username,
    String password, {
    String totp = '',
  }) async {
    try {
      final form = <String, String>{
        'username': username.trim(),
        'password': password,
        'app_name': 'Dropify',
      };
      if (totp.trim().isNotEmpty) form['totp'] = totp.trim();

      final response = await _dio.post(
        '/user/login',
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Origin': 'https://pixeldrain.com'},
        ),
      );

      final body = _asMap(response.data);

      if (response.statusCode == 201 && body['auth_key'] is String) {
        final key = body['auth_key'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPref, key);
        _applyKey(key);
        return const LoginResult(success: true);
      }

      final code = body['value'] as String? ?? '';
      switch (code) {
        case 'user_not_found':
          return const LoginResult(
              success: false,
              code: 'user_not_found',
              message: 'Username / email tidak ditemukan.');
        case 'password_incorrect':
          return const LoginResult(
              success: false,
              code: 'password_incorrect',
              message: 'Password salah.');
        case 'otp_required':
          return const LoginResult(
              success: false,
              code: 'otp_required',
              needsOtp: true,
              message: 'Akun ini memakai 2FA. Masukkan kode 6 digit.');
        case 'otp_incorrect':
          return const LoginResult(
              success: false,
              code: 'otp_incorrect',
              needsOtp: true,
              message: 'Kode 2FA salah.');
        case 'ip_rate_limit_reached':
          return const LoginResult(
              success: false,
              code: 'rate_limited',
              message: 'Terlalu banyak percobaan login. Coba lagi nanti.');
        default:
          final msg = body['message'] as String?;
          return LoginResult(
            success: false,
            message: msg ??
                'Login gagal (HTTP ${response.statusCode}). Coba lagi.',
          );
      }
    } on DioException catch (e) {
      return LoginResult(
        success: false,
        code: 'network',
        message: 'Gagal terhubung ke Pixeldrain: ${e.message ?? e.type.name}',
      );
    } catch (e) {
      return LoginResult(success: false, message: 'Error: $e');
    }
  }

  /// Info file publik (dipakai saat user menempel link orang lain).
  Future<Map<String, dynamic>?> getFileInfo(String id) async {
    try {
      final response = await _dio.get('/file/$id/info');
      if (response.statusCode == 200) return _asMap(response.data);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final response = await _dio.get('/user');
      if (response.statusCode == 200) return _asMap(response.data);
      return null;
    } catch (_) {
      return null;
    }
  }


  /// Header auth untuk request gambar/thumbnail.
  Map<String, String> get authHeaders => _authKey == null
      ? const {}
      : {
          'Authorization':
              'Basic ${base64Encode(utf8.encode(':$_authKey'))}',
        };

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PixeldrainException {
      rethrow;
    } on DioException catch (e) {
      throw PixeldrainException(
          'Gagal terhubung ke Pixeldrain: ${e.message ?? e.type.name}');
    }
  }

  void _check(Response response, {bool filesystem = false}) {
    final code = response.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    final body = _asMap(response.data);

    if (filesystem && (code == 401 || code == 403)) {
      throw PixeldrainException(
        'Fitur folder (filesystem) hanya tersedia untuk akun Pixeldrain '
        'berlangganan Pro. File kamu tetap bisa diakses lewat "All uploads".',
      );
    }

    final msg = (body['message'] ?? body['value'] ?? 'HTTP $code').toString();
    throw PixeldrainException(
      code == 401 || code == 403 ? 'Sesi habis, silakan login ulang.' : msg,
      unauthorized: code == 401 || code == 403,
    );
  }

  /// Semua file yang pernah di-upload akun ini (GET /user/files).
  Future<List<PdItem>> listUserFiles() => _guard(() async {
        final response = await _dio.get('/user/files');
        _check(response);
        final files = _asMap(response.data)['files'];
        if (files is! List) return <PdItem>[];
        return files
            .whereType<Map>()
            .map((e) => PdItem.fromUserFile(Map<String, dynamic>.from(e)))
            .toList();
      });

  /// Isi folder di filesystem Pixeldrain (GET /filesystem/me/...).
  Future<List<PdItem>> listDir(List<String> segments) => _guard(() async {
        final path =
            '/filesystem/me${segments.map((s) => '/${Uri.encodeComponent(s)}').join()}';
        final response = await _dio.get(path);
        _check(response, filesystem: true);
        final children = _asMap(response.data)['children'];
        if (children is! List) return <PdItem>[];
        return children
            .whereType<Map>()
            .map((e) => PdItem.fromFs(Map<String, dynamic>.from(e), segments))
            .toList();
      });

  Future<void> deleteFile(String id) => _guard(() async {
        final response = await _dio.delete('/file/$id');
        _check(response);
      });

  String _fsPath(List<String> segments) =>
      '/filesystem/me${segments.map((s) => '/${Uri.encodeComponent(s)}').join()}';

  /// Buat folder baru di filesystem.
  Future<void> createDir(List<String> parent, String name) => _guard(() async {
        final response = await _dio.post(
          _fsPath([...parent, name]),
          data: {'action': 'mkdir'},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        _check(response, filesystem: true);
      });

  /// Ganti nama file/folder.
  Future<void> rename(List<String> segments, String newName) => _guard(() async {
        if (segments.isEmpty) return;
        final parent = segments.sublist(0, segments.length - 1);
        final response = await _dio.post(
          _fsPath(segments),
          data: {
            'action': 'rename',
            'target': _fsPath([...parent, newName]),
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        _check(response, filesystem: true);
      });

  /// Hapus file/folder. Folder dihapus rekursif.
  Future<void> deleteFs(List<String> segments, {bool recursive = true}) =>
      _guard(() async {
        final response = await _dio.delete(
          _fsPath(segments),
          queryParameters: recursive ? {'recursive': ''} : null,
        );
        _check(response, filesystem: true);
      });

  /// Upload file langsung ke dalam folder filesystem.
  Future<String?> uploadToDir(
    List<String> parent,
    String path,
    String name,
    void Function(int sent, int total) onProgress,
  ) =>
      _guard(() async {
        final file = File(path);
        final length = await file.length();
        final response = await _dio.put(
          _fsPath([...parent, name]),
          data: file.openRead(),
          options: Options(
            headers: {
              Headers.contentLengthHeader: length,
              Headers.contentTypeHeader: _mimeForName(name),
            },
            sendTimeout: null,
            receiveTimeout: const Duration(minutes: 2),
          ),
          onSendProgress: onProgress,
        );
        _check(response, filesystem: true);
        return _asMap(response.data)['id']?.toString();
      });

  /// Mime berdasarkan ekstensi; penting supaya foto/video dikenali server.
  String _mimeForName(String name) {
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'jfif': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'avif': 'image/avif',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'flac': 'audio/flac',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'opus': 'audio/opus',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
      'tar': 'application/x-tar',
      'gz': 'application/gzip',
      'apk': 'application/vnd.android.package-archive',
      'txt': 'text/plain',
      'json': 'application/json',
      'csv': 'text/csv',
      'md': 'text/markdown',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  /// Upload file (PUT /file/{name}). Return id file.
  Future<String?> uploadFile(
    String path,
    String name,
    void Function(int sent, int total) onProgress,
  ) =>
      _guard(() async {
        final file = File(path);
        final length = await file.length();
        final response = await _dio.put(
          '/file/${Uri.encodeComponent(name)}',
          data: file.openRead(),
          options: Options(
            headers: {
              Headers.contentLengthHeader: length,
              Headers.contentTypeHeader: _mimeForName(name),
            },
            sendTimeout: null,
            receiveTimeout: const Duration(minutes: 2),
          ),
          onSendProgress: onProgress,
        );
        _check(response);
        return _asMap(response.data)['id']?.toString();
      });

  Future<void> logout() async {
    try {
      await _dio.delete('/user/session');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
    _authKey = null;
    _dio.options.headers.remove('Authorization');
  }
}
