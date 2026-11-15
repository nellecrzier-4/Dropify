import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Catatan kejadian aplikasi di perangkat.
///
/// Ditulis ke `Download/Dropify/dropify.log` (diputar kalau sudah besar) supaya
/// masalah yang hanya muncul di HP — unduhan macet, aplikasi tertutup sendiri —
/// bisa diperiksa tanpa memasang adb. Hanya kejadian penting, bukan setiap
/// potongan data.
class Diagnostics {
  Diagnostics._();

  static final Diagnostics instance = Diagnostics._();

  static const String fileName = 'dropify.log';
  static const int _maxBytes = 512 * 1024;

  final List<String> _buffer = <String>[];
  String? _folder;
  Timer? _flush;
  bool _installed = false;

  /// Folder tujuan log; disamakan dengan folder unduhan aplikasi.
  void configure(String folder) {
    if (_folder == folder) return;
    _folder = folder;
  }

  /// Pasang penangkap error Flutter supaya stack trace ikut tercatat.
  void install({String folder = '/storage/emulated/0/Download/Dropify'}) {
    configure(folder);
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      log('error', '${details.exceptionAsString()}\n${details.stack ?? ''}');
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log('crash', '$error\n$stack');
      return false;
    };
  }

  void log(String tag, String message) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final line = '[$stamp] $tag: $message';
    debugPrint(line);
    _buffer.add(line);
    _flush ??= Timer(const Duration(seconds: 2), _write);
  }

  Future<void> _write() async {
    _flush = null;
    final folder = _folder;
    if (folder == null || _buffer.isEmpty) return;
    final lines = _buffer.join('\n');
    _buffer.clear();
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && await file.length() > _maxBytes) {
        final old = File('${file.path}.old');
        if (await old.exists()) await old.delete();
        await file.rename(old.path);
      }
      await file.writeAsString('$lines\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Log tidak boleh mengganggu transfer.
    }
  }
}
