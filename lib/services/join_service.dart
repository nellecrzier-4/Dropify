import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/file_types.dart';
import 'native_downloads.dart';

enum JoinStatus { idle, running, done, error }

/// Penggabungan bagian berkas (nama.part1.zip + nama.part2.zip).
///
/// Berjalan di layanan bersama, bukan di layar, sehingga tetap lanjut ketika
/// pengguna meninggalkan halaman Join Parts — dan progresnya bisa ditampilkan
/// di mana saja.
class JoinService extends ChangeNotifier {
  JoinService._();

  static final JoinService instance = JoinService._();

  JoinStatus status = JoinStatus.idle;
  String name = '';
  String? path;
  String? error;
  int totalBytes = 0;
  int doneBytes = 0;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _started = DateTime.now();

  bool get running => status == JoinStatus.running;

  double get progress => totalBytes <= 0 ? 0 : (doneBytes / totalBytes).clamp(0.0, 1.0);

  Duration? get eta {
    final seconds = DateTime.now().difference(_started).inSeconds;
    if (seconds < 2 || doneBytes <= 0) return null;
    final speed = doneBytes / seconds;
    if (speed <= 0) return null;
    return Duration(seconds: ((totalBytes - doneBytes) / speed).round());
  }

  Future<String?> join({
    required List<File> parts,
    required String outputPath,
    required String outputName,
    bool deleteParts = true,
  }) async {
    if (running) return null;
    status = JoinStatus.running;
    name = outputName;
    path = null;
    error = null;
    doneBytes = 0;
    _started = DateTime.now();
    final existing = <File>[];
    totalBytes = 0;
    for (final file in parts) {
      try {
        if (!await file.exists()) continue;
        existing.add(file);
        totalBytes += await file.length();
      } catch (_) {}
    }
    notifyListeners();

    final output = File(outputPath);
    RandomAccessFile? raf;
    try {
      if (await output.exists()) await output.delete();
      raf = await output.open(mode: FileMode.write);
      final buffer = Uint8List(4 * 1024 * 1024);
      for (final file in existing) {
        final input = await file.open();
        try {
          while (true) {
            final read = await input.readInto(buffer);
            if (read <= 0) break;
            await raf.writeFrom(buffer, 0, read);
            doneBytes += read;
            _report();
          }
        } finally {
          await input.close();
        }
      }
      await raf.flush();
      await raf.close();
      raf = null;

      if (deleteParts) {
        for (final file in existing) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      await NativeDownloads.scanFile(output.path);
      status = JoinStatus.done;
      path = output.path;
      doneBytes = totalBytes;
      NativeDownloads.cancelNotification(7200);
      notifyListeners();
      return output.path;
    } catch (e) {
      status = JoinStatus.error;
      error = '$e';
      notifyListeners();
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  void reset() {
    if (running) return;
    status = JoinStatus.idle;
    name = '';
    path = null;
    error = null;
    totalBytes = 0;
    doneBytes = 0;
    notifyListeners();
  }

  void _report() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 400) return;
    _lastNotify = now;
    NativeDownloads.notifyDownload(
      id: 7200,
      title: name,
      text: '${formatSize(doneBytes)} / ${formatSize(totalBytes)}',
      progress: progress,
    );
    notifyListeners();
  }
}
