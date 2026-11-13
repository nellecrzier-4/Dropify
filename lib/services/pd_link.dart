import 'pixeldrain_bypass.dart';

/// Tipe link Pixeldrain yang bisa dibuka dari luar.
enum PdLinkType { file, album, folder }

class PdLink {
  const PdLink({required this.type, required this.id});

  final PdLinkType type;
  final String id;

  bool get isFile => type == PdLinkType.file;

  /// Link bypass untuk file ini (album/folder memakai endpoint zip).
  String? get bypassUrl {
    switch (type) {
      case PdLinkType.file:
        return PixeldrainBypass.linkForFileId(id);
      case PdLinkType.album:
        return PixeldrainBypass.albumZipUrl(id);
      case PdLinkType.folder:
        return PixeldrainBypass.folderZipUrl(id);
    }
  }

  /// Terima link pixeldrain.com / pixeldra.in / api, atau id polos.
  static PdLink? parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    // ID polos (8 karakter alfanumerik).
    final bare = RegExp(r'^[A-Za-z0-9]{6,12}$');
    if (bare.hasMatch(value)) {
      return PdLink(type: PdLinkType.file, id: value);
    }

    // Buang query & fragment.
    value = value.split('#').first.split('?').first;
    if (!value.startsWith('http')) value = 'https://$value';

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('pixeldrain') && !host.contains('pixeldra.in')) {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    // /api/file/<id>, /api/list/<id>/..., /u/<id>, /l/<id>, /d/<id>
    var index = 0;
    if (segments.first == 'api' && segments.length > 1) index = 1;
    final kind = segments[index];
    final id = segments.length > index + 1 ? segments[index + 1] : '';

    if (id.isEmpty) return null;

    switch (kind) {
      case 'u':
      case 'file':
        return PdLink(type: PdLinkType.file, id: id);
      case 'l':
      case 'list':
        return PdLink(type: PdLinkType.album, id: id);
      case 'd':
        return PdLink(type: PdLinkType.folder, id: id);
      default:
        return null;
    }
  }
}
