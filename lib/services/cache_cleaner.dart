import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Membersihkan cache sementara (potongan file saat upload, file sementara lain).
class CacheCleaner {
  CacheCleaner._();

  static Future<int> clearTempCache() async {
    var freed = 0;
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is File) {
            freed += await entity.length();
            await entity.delete();
          } else if (entity is Directory) {
            await for (final child in entity.list(recursive: true)) {
              if (child is File) freed += await child.length();
            }
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return freed;
  }

  /// Hapus sisa potongan upload yang tertinggal (mis. aplikasi ditutup).
  static Future<int> clearUploadParts() async {
    var freed = 0;
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && RegExp(r'\.part\d+\.[^.]+$').hasMatch(entity.path)) {
          freed += await entity.length();
          await entity.delete();
        }
      }
    } catch (_) {}
    return freed;
  }
}
