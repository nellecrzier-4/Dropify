import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../services/app_settings.dart';
import '../services/download_service.dart';
import '../services/native_downloads.dart';
import '../services/pixeldrain_bypass.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'kit.dart';
import 'motion.dart';
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
      task.error == 'storage_permission'
          ? s.storagePermission
          : (task.error ?? ''),
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

  void copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ItemSheet(
      title: item.name,
      subtitle: subtitle,
      icon: item.isDir ? Icons.folder_rounded : item.category.icon,
      color: item.isDir ? AppColors.accent : item.category.color,
      actions: [
        _Action(
          icon: Icons.download_rounded,
          label: s.download,
          subtitle: bypass != null
              ? s.downloadSubtitleBypass
              : s.downloadSubtitleDirect,
          highlight: true,
          onTap: () {
            Navigator.pop(sheetContext);
            downloadItem(context, ctrl, item);
          },
        ),
        _Action(
          icon: Icons.link_rounded,
          label: s.copyDownloadLink,
          onTap: () {
            Navigator.pop(sheetContext);
            copy(context, downloadLinkFor(item), s.linkCopied);
          },
        ),
        _Action(
          icon: Icons.share_outlined,
          label: s.shareLink,
          onTap: () {
            Navigator.pop(sheetContext);
            NativeDownloads.shareText(downloadLinkFor(item));
          },
        ),
        _Action(
          icon: Icons.open_in_new_rounded,
          label: s.openInBrowser,
          onTap: () {
            Navigator.pop(sheetContext);
            openItem(item);
          },
        ),
        _Action(
          icon: Icons.public_rounded,
          label: s.copyPixeldrainLink,
          onTap: () {
            Navigator.pop(sheetContext);
            copy(context, item.webUrl, s.pixeldrainLinkCopied);
          },
        ),
        if (item.fromUserFiles || item.fsPath.isNotEmpty)
          _Action(
            icon: Icons.delete_outline_rounded,
            label: s.delete,
            danger: true,
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
  );
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool highlight;
}

/// Sheet aksi file: panel melayang dengan header file dan baris berikon.
class _ItemSheet extends StatelessWidget {
  const _ItemSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GlowIcon(icon: icon, size: 44, color: color),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < actions.length; i++)
                Stagger(
                  index: i,
                  step: const Duration(milliseconds: 35),
                  slide: 10,
                  child: _ActionRow(action: actions[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final scheme = AppColors.scheme;
    final Color titleColor = a.danger
        ? AppColors.danger
        : (a.highlight ? scheme.primary : AppColors.text);

    return Pressable(
      onTap: a.onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            GlowIcon(
              icon: a.icon,
              size: 42,
              color: a.danger ? AppColors.danger : scheme.primary,
              filled: a.highlight,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (a.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
