import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/drive_controller.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../utils/errors.dart';
import '../screens/settings_screen.dart';
import '../services/download_service.dart';
import '../screens/pd_captcha_screen.dart';
import '../services/native_downloads.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'kit.dart';
import 'motion.dart';
import 'wave_progress.dart';

/// Sheet "Transfers": tab Downloads (link bypass) dan Uploads.
void showTransfers(
  BuildContext context,
  DriveController ctrl, {
  int initialTab = 0,
}) {
  showExpressiveSheet(
    context: context,
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
    final scheme = AppColors.scheme;
    final height = MediaQuery.of(context).size.height * 0.76;

    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.ctrl, widget.ctrl.downloads]),
          builder: (context, _) {
            final ctrl = widget.ctrl;
            final active = ctrl.downloads.activeCount;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.transfers,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: s.downloadHistory,
                        onPressed: () => Navigator.push(
                          context,
                          SharedAxisPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                        icon: const Icon(Icons.history_rounded, size: 20),
                      ),
                      AnimatedSize(
                        duration: Motion.fast,
                        child: ctrl.downloads.tasks.any((t) => !t.isActive)
                            ? TextButton(
                                onPressed: ctrl.downloads.clearFinished,
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurfaceVariant,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(s.clear),
                              )
                            : const SizedBox(width: 0, height: 0),
                      ),
                    ],
                  ),
                ),
                if (!_notificationsOn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                    child: _PermissionCard(onAllow: _askPermission),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    labelColor: scheme.onSecondaryContainer,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                          text: active > 0
                              ? '${s.downloads} · $active'
                              : s.downloads),
                      Tab(text: s.uploads),
                    ],
                  ),
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
    final scheme = AppColors.scheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          GlowIcon(
            icon: Icons.notifications_active_outlined,
            size: 38,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              s.notificationsCard,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onAllow(),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSecondaryContainer,
              shape: const StadiumBorder(),
            ),
            child: Text(s.allow),
          ),
        ],
      ),
    );
  }
}

/// Baris transfer: ikon tonal, judul, progres, dan aksi di kanan.
class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.progress,
    this.trailing,
    this.onTap,
    this.index = 0,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget subtitle;
  final double? progress;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: GlowIcon(
              key: ValueKey(icon),
              icon: icon,
              size: 42,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 9),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                    duration: Motion.slow,
                    curve: Motion.emphasized,
                    builder: (context, value, _) => WaveProgressBar(
                      value: value,
                      height: 9,
                      animate: false,
                    ),
                  ),
                  const SizedBox(height: 7),
                ] else
                  const SizedBox(height: 3),
                subtitle,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );

    return Stagger(
      index: index,
      step: const Duration(milliseconds: 40),
      slide: 12,
      child: Surface(
        radius: AppRadii.xl,
        padding: EdgeInsets.zero,
        clip: true,
        onTap: onTap,
        child: content,
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
    await showExpressiveSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stagger(
                index: 0,
                slide: 8,
                child: Row(
                  children: [
                    GlowIcon(
                      icon: Icons.error_outline_rounded,
                      size: 44,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task.name,
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
                          const SizedBox(height: 3),
                          Text(
                            describeDownloadError(
                              context,
                              task.error ?? s.downloadDetails,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...staggered(
                <Widget>[
                  if (task.error != null &&
                      (task.error!.contains('captcha') ||
                          task.error!.contains('403')))
                    _DetailAction(
                      icon: Icons.verified_user_outlined,
                      title: 'Verifikasi captcha',
                      subtitle: 'Selesaikan di halaman Pixeldrain, lalu unduh ulang',
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final id = (task.item.id ?? '').trim().isNotEmpty
                            ? task.item.id!
                            : (fileIdFromUrl(task.url ?? task.directUrl) ?? '');
                        if (id.isEmpty) return;
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute<bool>(
                            builder: (_) => PdCaptchaScreen(fileId: id),
                          ),
                        );
                        if (ok == true) controller.downloads.retry(task.id);
                      },
                    ),
                  if (task.url != null)
                    _DetailAction(
                      icon: Icons.link_rounded,
                      title: s.copyLink,
                      subtitle: task.url,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: task.url!));
                        Navigator.pop(sheetContext);
                      },
                    ),
                  _DetailAction(
                    icon: Icons.refresh_rounded,
                    title: s.retry,
                    subtitle: s.attemptInfo(
                      task.attempts,
                      task.viaBypass ? s.viaBypass : s.viaPixeldrain,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      controller.downloads.retry(task.id);
                    },
                  ),
                  _DetailAction(
                    icon: Icons.public_rounded,
                    title: s.tryPixeldrain,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      controller.downloads.retryWithoutBypass(task.id);
                    },
                  ),
                ],
                start: 1,
                step: const Duration(milliseconds: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, DownloadTask task) async {
    final ok = await ctrl.downloads
        .openFile(task)
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

  String _subtitle(BuildContext context, AppStrings s, DownloadTask t) {
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
          describeDownloadError(context, t.error).isEmpty
              ? '—'
              : describeDownloadError(context, t.error),
        );
    }
  }

  IconData _icon(DownloadTask t) {
    switch (t.status) {
      case DownloadStatus.preparing:
      case DownloadStatus.queued:
        return Icons.schedule_rounded;
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.done:
        return Icons.check_rounded;
      case DownloadStatus.canceled:
        return Icons.close_rounded;
      case DownloadStatus.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tasks = ctrl.downloads.tasks;
    if (tasks.isEmpty) {
      return const _EmptyTransfers(
        icon: Icons.download_outlined,
        emptyKey: _EmptyKind.downloads,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = tasks[i];
        final failed = t.status == DownloadStatus.error;
        return _TransferRow(
          index: i,
          icon: _icon(t),
          iconColor: failed
              ? AppColors.danger
              : t.status == DownloadStatus.done
                  ? AppColors.scheme.primary
                  : AppColors.scheme.onSurfaceVariant,
          title: t.name,
          progress: t.status == DownloadStatus.downloading ? t.progress : null,
          subtitle: Text(
            _subtitle(context, s, t),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  failed ? AppColors.danger : AppColors.scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          trailing: t.isActive
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.scheme.onSurfaceVariant, size: 20),
                  onPressed: () => ctrl.downloads.cancel(t.id),
                )
              : t.status == DownloadStatus.done
                  ? IconButton(
                      icon: Icon(Icons.folder_open_rounded,
                          color: AppColors.scheme.primary, size: 20),
                      onPressed: () => _open(context, t),
                    )
                  : IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: AppColors.scheme.onSurfaceVariant, size: 20),
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

enum _EmptyKind { downloads, uploads }

class _EmptyTransfers extends StatelessWidget {
  const _EmptyTransfers({required this.icon, required this.emptyKey});

  final IconData icon;
  final _EmptyKind emptyKey;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Stagger(
          child: DashedPanel(
            radius: AppRadii.xl,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                OrbIcon(icon: icon, size: 96),
                const SizedBox(height: 16),
                Text(
                  emptyKey == _EmptyKind.downloads
                      ? s.noDownloads
                      : s.noUploads,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.scheme.onSurfaceVariant,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (emptyKey == _EmptyKind.downloads) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.noDownloadsHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          children: [
            GlowIcon(
              icon: icon,
              size: 40,
              color: scheme.primary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
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

class _UploadsTab extends StatelessWidget {
  final DriveController ctrl;
  const _UploadsTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (ctrl.uploads.isEmpty) {
      return const _EmptyTransfers(
        icon: Icons.upload_outlined,
        emptyKey: _EmptyKind.uploads,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: ctrl.uploads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = ctrl.uploads[i];
        final uploading = t.status == UploadStatus.uploading;
        return _TransferRow(
          index: i,
          icon: switch (t.status) {
            UploadStatus.uploading => Icons.arrow_upward_rounded,
            UploadStatus.done => Icons.check_rounded,
            UploadStatus.error => Icons.error_outline_rounded,
          },
          iconColor: t.status == UploadStatus.error
              ? AppColors.danger
              : AppColors.scheme.primary,
          title: t.name,
          progress: uploading ? t.progress : null,
          subtitle: Text(
            uploading
                ? [
                    if (t.parts > 1) s.partOf(t.currentPart, t.parts),
                    s.uploadingDetail(
                      formatSize(t.sent),
                      formatSize(t.size),
                      t.speed > 0 ? formatSize(t.speed.round()) : '—',
                    ),
                  ].join(' · ')
                : (t.status == UploadStatus.done
                    ? s.uploadDoneDetail(formatSize(t.size))
                    : s.failedDetail(t.error ?? '')),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.status == UploadStatus.error
                  ? AppColors.danger
                  : AppColors.scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              switch (t.status) {
                UploadStatus.uploading => Icons.arrow_upward_rounded,
                UploadStatus.done => Icons.check_circle_outline_rounded,
                UploadStatus.error => Icons.error_outline_rounded,
              },
              size: 20,
              color: AppColors.scheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
