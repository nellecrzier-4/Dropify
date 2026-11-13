import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/download_service.dart';
import '../screens/settings_screen.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'wave_progress.dart';

/// Sheet "Transfers": tab Downloads (link bypass) dan Uploads.
void showTransfers(
  BuildContext context,
  DriveController ctrl, {
  int initialTab = 0,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    builder: (_) => DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: _TransfersSheet(ctrl: ctrl),
    ),
  );
}

class _TransfersSheet extends StatefulWidget {
  final DriveController ctrl;
  const _TransfersSheet({required this.ctrl});

  @override
  State<_TransfersSheet> createState() => _TransfersSheetState();
}

class _TransfersSheetState extends State<_TransfersSheet> {
  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final enabled = await NativeDownloads.notificationsEnabled();
    if (mounted) setState(() => _notificationsOn = enabled);
  }

  Future<void> _askPermission() async {
    final granted = await NativeDownloads.requestPermissions();
    if (mounted) setState(() => _notificationsOn = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.notificationsDenied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final height = MediaQuery.of(context).size.height * 0.76;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.ctrl, widget.ctrl.downloads]),
          builder: (context, _) {
            final ctrl = widget.ctrl;
            final active = ctrl.downloads.activeCount;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                  child: Row(
                    children: [
                      Text(
                        s.transfers,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: s.downloadHistory,
                        icon: const Icon(Icons.history, color: AppColors.muted),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        ),
                      ),
                      if (ctrl.downloads.tasks.any((t) => !t.isActive))
                        TextButton(
                          onPressed: ctrl.downloads.clearFinished,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(s.clear),
                        ),
                    ],
                  ),
                ),
                if (!_notificationsOn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                    child: _PermissionCard(onAllow: _askPermission),
                  ),
                TabBar(
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.text,
                  unselectedLabelColor: AppColors.muted,
                  tabs: [
                    Tab(text: active > 0 ? '${s.downloads} · $active' : s.downloads),
                    Tab(text: s.uploads),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DownloadsTab(ctrl: ctrl),
                      _UploadsTab(ctrl: ctrl),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onAllow});

  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.notificationsCard,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onAllow(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
            child: Text(s.allow),
          ),
        ],
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  final DriveController ctrl;
  const _DownloadsTab({required this.ctrl});

  Future<void> _showDetails(BuildContext context, DownloadTask task) async {
    final s = context.s;
    final controller = ctrl;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(task.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                task.error == 'storage_permission'
                    ? s.storagePermission
                    : (task.error ?? s.downloadDetails),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
            if (task.url != null)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(s.copyLink),
                subtitle: Text(task.url!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: task.url!));
                  Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(s.retry),
              subtitle: Text(
                s.attemptInfo(task.attempts, task.viaBypass ? s.viaBypass : s.viaPixeldrain),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.downloads.retry(task.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(s.tryPixeldrain),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.downloads.retryWithoutBypass(task.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, DownloadTask task) async {
    final ok = await ctrl.downloads.openFile(task)
        .then((_) => true)
        .catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.s.openFileFailed} ${task.path ?? ''}'),
        ),
      );
    }
  }

  String _subtitle(AppStrings s, DownloadTask t) {
    switch (t.status) {
      case DownloadStatus.preparing:
        return s.preparingLink;
      case DownloadStatus.queued:
        return s.waitingInQueue;
      case DownloadStatus.downloading:
        if (t.waiting) return s.waitingNetwork;
        final total = t.size > 0 ? formatSize(t.size) : '—';
        final speed = t.speed > 0 ? '${formatSize(t.speed.round())}/s' : '—';
        final via = t.viaBypass ? s.viaBypass : s.viaPixeldrain;
        return s.downloadingDetail(formatSize(t.received), total, speed, via);
      case DownloadStatus.done:
        return s.doneDetail(formatSize(t.size));
      case DownloadStatus.canceled:
        return s.canceled;
      case DownloadStatus.error:
        return s.failedDetail(
          t.error == 'storage_permission' ? s.storagePermission : (t.error ?? '—'),
        );
    }
  }

  IconData _icon(DownloadTask t) {
    switch (t.status) {
      case DownloadStatus.preparing:
      case DownloadStatus.queued:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.done:
        return Icons.check_circle_outline;
      case DownloadStatus.canceled:
        return Icons.cancel_outlined;
      case DownloadStatus.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tasks = ctrl.downloads.tasks;
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text(s.noDownloads, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          Text(
            s.noDownloadsHint,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        final failed = t.status == DownloadStatus.error;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(
            _icon(t),
            color: failed
                ? AppColors.danger
                : t.status == DownloadStatus.done
                    ? AppColors.primary
                    : AppColors.muted,
          ),
          title: Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.status == DownloadStatus.downloading) ...[
                const SizedBox(height: 10),
                WaveProgressBar(
                  value: t.progress,
                  height: 10,
                  animate: true,
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 4),
              Text(
                _subtitle(s, t),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: failed ? AppColors.danger : AppColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          trailing: t.isActive
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  onPressed: () => ctrl.downloads.cancel(t.id),
                )
              : t.status == DownloadStatus.done
                  ? IconButton(
                      icon: Icon(
                        Icons.folder_open,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _open(context, t),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.muted),
                      onPressed: () => ctrl.downloads.retry(t.id),
                    ),
          onTap: t.status == DownloadStatus.done
              ? () => _open(context, t)
              : t.status == DownloadStatus.error
                  ? () => _showDetails(context, t)
                  : null,
        );
      },
    );
  }
}

class _UploadsTab extends StatelessWidget {
  final DriveController ctrl;
  const _UploadsTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (ctrl.uploads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text(s.noUploads, style: const TextStyle(color: AppColors.muted)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        for (final t in ctrl.uploads)
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            subtitle: t.status == UploadStatus.uploading
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      WaveProgressBar(value: t.progress, height: 10),
                      const SizedBox(height: 8),
                      Text(
                        s.uploadingDetail(
                          formatSize(t.sent),
                          formatSize(t.size),
                          t.speed > 0 ? formatSize(t.speed.round()) : '—',
                        ),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  )
                : Text(
                    t.status == UploadStatus.done
                        ? s.uploadDoneDetail(formatSize(t.size))
                        : s.failedDetail(t.error ?? ''),
                    style: TextStyle(
                      color: t.status == UploadStatus.done
                          ? AppColors.muted
                          : AppColors.danger,
                      fontSize: 12.5,
                    ),
                  ),
            trailing: Icon(
              switch (t.status) {
                UploadStatus.uploading => Icons.arrow_upward,
                UploadStatus.done => Icons.check_circle_outline,
                UploadStatus.error => Icons.error_outline,
              },
              color: AppColors.muted,
            ),
          ),
      ],
    );
  }
}
