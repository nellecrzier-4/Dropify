import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

enum FileCategory { archives, videos, apps, images, audio, documents, other }

extension FileCategoryX on FileCategory {
  String get label => switch (this) {
        FileCategory.archives => 'Archives',
        FileCategory.videos => 'Videos',
        FileCategory.apps => 'Apps',
        FileCategory.images => 'Images',
        FileCategory.audio => 'Audio',
        FileCategory.documents => 'Documents',
        FileCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        FileCategory.archives => Icons.folder_zip_outlined,
        FileCategory.videos => Icons.movie_outlined,
        FileCategory.apps => Icons.android,
        FileCategory.images => Icons.image_outlined,
        FileCategory.audio => Icons.music_note_outlined,
        FileCategory.documents => Icons.description_outlined,
        FileCategory.other => Icons.insert_drive_file_outlined,
      };

  Color get color => switch (this) {
        FileCategory.archives => AppColors.archives,
        FileCategory.videos => AppColors.videos,
        FileCategory.apps => AppColors.apps,
        FileCategory.images => AppColors.images,
        FileCategory.audio => AppColors.audio,
        FileCategory.documents => AppColors.documents,
        FileCategory.other => AppColors.other,
      };

  String countLabel(int n) {
    final s = n == 1;
    return switch (this) {
      FileCategory.archives => '$n ${s ? 'file' : 'files'}',
      FileCategory.videos => '$n ${s ? 'video' : 'videos'}',
      FileCategory.apps => '$n ${s ? 'app' : 'apps'}',
      FileCategory.images => '$n ${s ? 'photo' : 'photos'}',
      FileCategory.audio => '$n ${s ? 'track' : 'tracks'}',
      FileCategory.documents => '$n ${s ? 'document' : 'documents'}',
      FileCategory.other => '$n ${s ? 'file' : 'files'}',
    };
  }
}

const _archiveExt = {
  'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'iso', 'zst', 'cab'
};
const _appExt = {'apk', 'xapk', 'apks', 'aab', 'exe', 'msi', 'dmg', 'deb', 'appimage'};
const _docExt = {
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'csv',
  'epub', 'odt', 'ods', 'odp', 'rtf'
};
const _imgExt = {
  'jpg', 'jpeg', 'jfif', 'png', 'gif', 'webp', 'heic', 'heif', 'avif',
  'bmp', 'tif', 'tiff', 'svg', 'jxl'
};

FileCategory categorize(String name, String mime) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  var m = mime.toLowerCase();
  if (m == 'application/octet-stream' || m == 'binary/octet-stream') m = '';
  if (_appExt.contains(ext) || m.contains('android.package')) {
    return FileCategory.apps;
  }
  if (m.startsWith('video/')) return FileCategory.videos;
  if (m.startsWith('image/')) return FileCategory.images;
  if (m.startsWith('audio/')) return FileCategory.audio;
  if (_archiveExt.contains(ext) ||
      m.contains('zip') ||
      m.contains('rar') ||
      m.contains('7z') ||
      m.contains('tar') ||
      m.contains('compressed')) {
    return FileCategory.archives;
  }
  if (_docExt.contains(ext) || m == 'application/pdf' || m.startsWith('text/')) {
    return FileCategory.documents;
  }
  const vidExt = {'mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v', '3gp', 'ts'};
  const audExt = {'mp3', 'flac', 'wav', 'm4a', 'ogg', 'opus', 'aac', 'wma'};
  if (vidExt.contains(ext)) return FileCategory.videos;
  if (_imgExt.contains(ext)) return FileCategory.images;
  if (audExt.contains(ext)) return FileCategory.audio;
  return FileCategory.other;
}

String formatSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1000;
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v.toStringAsFixed(1)} ${units[i]}';
}

String formatDate(DateTime? d) =>
    d == null ? '' : DateFormat('d MMM yyyy').format(d);

String formatAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 10) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
