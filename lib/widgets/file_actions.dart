import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/download_service.dart';
import '../services/app_settings.dart';
import '../services/native_downloads.dart';
import '../services/pixeldrain_bypass.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'transfers_sheet.dart';

/// Membuka halaman file di browser. Untuk file dengan id, yang dibuka adalah
/// link bypass supaya unduhan di browser juga bebas limit.
Future<void> openItem(PdItem item) {
  final url = PixeldrainBypass.linkForFileId(item.id) ?? item.webUrl;
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Link download yang dipakai aplikasi: bypass kalau memungkinkan.
String downloadLinkFor(PdItem item) =>
    PixeldrainBypass.linkForFileId(item.id) ?? item.webUrl;

bool _askingNotifications = false;

/// Minta izin "Akses semua file" supaya bisa menulis ke Download/Dropify.
Future<void> ensureStorageAccess(BuildContext context) async {
  if (await NativeDownloads.hasAllFilesAccess()) return;
  await NativeDownloads.requestAllFilesAccess();
  if (!context.mounted) return;
  if (!await NativeDownloads.hasAllFilesAccess()) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.s.storagePermissionHint),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

/// Minta izin notifikasi (sekali) supaya progres download tampil realtime.
Future<void> ensureNotificationPermission() async {
  if (_askingNotifications) return;
  if (await NativeDownloads.notificationsEnabled()) return;
  _askingNotifications = true;
  try {
    await NativeDownloads.requestPermissions();
  } finally {
    _askingNotifications = false;
  }
}

/// Mulai unduh file lewat link bypass, lalu tampilkan progres singkat.
Future<void> downloadItem(
  BuildContext context,
  DriveController ctrl,
  PdItem item,
) async {
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  await ensureNotificationPermission();
  await ensureStorageAccess(context);
  if (!context.mounted) return;
  final task = await ctrl.downloadFile(item);
  if (task == null || !context.mounted) return;

  final String text;
  if (task.status == DownloadStatus.error) {
    text = s.downloadFailedSnack(
      task.name,
      task.error == 'storage_permission' ? s.storagePermission : (task.error ?? ''),
    );
  } else if (!task.isActive && task.status == DownloadStatus.done) {
    text = '${task.name} ${s.alreadyDownloaded}';
  } else if (task.received > 0 || task.status == DownloadStatus.downloading) {
    text = s.downloadingSnack(task.name);
  } else {
    text = s.downloadStartedSnack(task.name);
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      action: SnackBarAction(
        label: s.downloads,
        onPressed: () => showTransfers(context, ctrl),
      ),
    ),
  );
}

void showItemActions(BuildContext context, DriveController ctrl, PdItem item) {
  final s = context.s;
  final bypass = PixeldrainBypass.linkForFileId(item.id);
  final subtitle = [
    if (item.size > 0) formatSize(item.size),
    if (!item.isDir)
      bypass != null ? 'via ${PixeldrainBypass.mirror}' : 'Pixeldrain',
  ].join(' · ');

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle.isEmpty
                ? null
                : Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
          ),
          ListTile(
            leading: Icon(Icons.download, color: AppColors.primary),
            title: Text(
              s.download,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              bypass != null ? s.downloadSubtitleBypass : s.downloadSubtitleDirect,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              downloadItem(context, ctrl, item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(s.copyDownloadLink),
            onTap: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: downloadLinkFor(item)));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(s.linkCopied)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(s.shareLink),
            onTap: () {
              Navigator.pop(sheetContext);
              NativeDownloads.shareText(downloadLinkFor(item));
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(s.openInBrowser),
            onTap: () {
              Navigator.pop(sheetContext);
              openItem(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(s.copyPixeldrainLink),
            onTap: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: item.webUrl));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(s.pixeldrainLinkCopied)));
            },
          ),
          if (item.fromUserFiles || item.fsPath.isNotEmpty)
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(
                s.delete,
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final needsConfirm = AppSettings.instance.confirmDelete;
                if (!needsConfirm) {
                  final err = item.fromUserFiles
                      ? await ctrl.deleteItem(item)
                      : await ctrl.deleteFsItem(item);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  }
                  return;
                }
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(s.deleteFileTitle),
                    content: Text(s.deleteFileBody(item.name)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: Text(s.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: Text(s.delete),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                final err = item.fromUserFiles
                    ? await ctrl.deleteItem(item)
                    : await ctrl.deleteFsItem(item);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
        ],
      ),
    ),
  );
}
