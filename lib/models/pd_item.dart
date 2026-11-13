import '../utils/file_types.dart';

const kPdApi = 'https://pixeldrain.com/api';

/// Satu file atau folder di Pixeldrain.
class PdItem {
  final String? id;
  final String name;
  final int size;
  final String mime;
  final DateTime? date;
  final bool isDir;

  /// Path relatif terhadap /filesystem/me (tanpa "me").
  final List<String> fsPath;

  /// true kalau berasal dari /user/files (bisa dihapus lewat id).
  final bool fromUserFiles;

  const PdItem({
    this.id,
    required this.name,
    this.size = 0,
    this.mime = '',
    this.date,
    this.isDir = false,
    this.fsPath = const [],
    this.fromUserFiles = false,
  });

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory PdItem.fromUserFile(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    return PdItem(
      id: id,
      name: (j['name'] ?? id ?? 'file').toString(),
      size: _int(j['size']),
      mime: (j['mime_type'] ?? '').toString(),
      date: _date(j['date_upload']),
      fromUserFiles: true,
    );
  }

  factory PdItem.fromFs(Map<String, dynamic> j, List<String> parent) {
    final name = (j['name'] ?? '').toString();
    final rawId = j['id']?.toString();
    return PdItem(
      id: (rawId == null || rawId.isEmpty) ? null : rawId,
      name: name,
      size: _int(j['file_size']),
      mime: (j['file_type'] ?? '').toString(),
      date: _date(j['modified'] ?? j['created']),
      isDir: j['type'] == 'dir',
      fsPath: [...parent, name],
    );
  }

  FileCategory get category => isDir ? FileCategory.other : categorize(name, mime);

  String get _fsUrl =>
      '$kPdApi/filesystem/me/${fsPath.map(Uri.encodeComponent).join('/')}';

  String get thumbnailUrl => id != null
      ? '$kPdApi/file/$id/thumbnail?width=256&height=256'
      : '$_fsUrl?thumbnail';

  String get webUrl => id != null ? 'https://pixeldrain.com/u/$id' : _fsUrl;
}
