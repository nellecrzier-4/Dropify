import 'package:flutter/widgets.dart';

import '../l10n/locale_controller.dart';

/// Terjemahkan kode error internal jadi teks yang bisa dibaca pengguna.
String describeDownloadError(BuildContext context, String? code) {
  switch (code) {
    case 'storage_permission':
      return context.s.storagePermission;
    case 'pixeldrain_rate_limited':
      return context.s.downloadNeedsPlan;
    default:
      return code ?? '';
  }
}
