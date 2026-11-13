import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_tile.dart';
import '../widgets/storage_card.dart';
import '../widgets/sync_card.dart';
import '../widgets/transfers_sheet.dart';
import '../widgets/wave_progress.dart';
import 'file_list_screen.dart';

class HomeTab extends StatelessWidget {
  final DriveController ctrl;
  final VoidCallback onLogout;
  const HomeTab({super.key, required this.ctrl, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SafeArea(
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final recent = ctrl.files.toList()
            ..sort((a, b) =>
                (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
          final total = ctrl.files.fold<int>(0, (sum, f) => sum + f.size);
          final initial =
              ctrl.username.isEmpty ? '?' : ctrl.username[0].toUpperCase();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.cloud_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Dropify',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: ctrl.downloads,
                    builder: (context, _) {
                      if (!ctrl.downloads.hasActive) {
                        return const SizedBox.shrink();
                      }
                      final active =
                          ctrl.downloads.tasks.where((t) => t.isActive).toList();
                      final speed = active.fold<double>(0, (a, t) => a + t.speed);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: AppColors.cardHigh,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => showTransfers(context, ctrl),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.downloading,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    speed > 0
                                        ? '${formatSize(speed.round())}/s'
                                        : '…',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.cardHigh,
                    onSelected: (v) async {
                      if (v == 'logout') onLogout();
                      if (v == 'settings') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                            ctrl.username.isEmpty ? 'Pixeldrain' : ctrl.username),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            const Icon(Icons.tune, size: 18),
                            const SizedBox(width: 10),
                            Text(s.settings),
                          ],
                        ),
                      ),
                      PopupMenuItem(value: 'logout', child: Text(s.logout)),
                    ],
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: AppColors.cardHigh,
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                formatSize(total),
                style: const TextStyle(
                  fontSize: 44,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${ctrl.files.length} ${s.files.toLowerCase()}'
                '${ctrl.lastSync == null ? '' : ' · ${formatAgo(ctrl.lastSync!)}'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.upload_file_rounded,
                    label: s.uploadFile,
                    primary: true,
                    onTap: () {
                      showTransfers(context, ctrl, initialTab: 1);
                      ctrl.pickAndUpload();
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.link_rounded,
                    label: s.download,
                    onTap: () => showTransfers(context, ctrl),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: s.files,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FileListScreen(ctrl: ctrl, search: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.tune_rounded,
                    label: s.settings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListenableBuilder(
                listenable: ctrl.downloads,
                builder: (context, _) => ctrl.downloads.hasActive
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ActiveDownloadsCard(ctrl: ctrl),
                      )
                    : const SizedBox.shrink(),
              ),
              SyncCard(ctrl: ctrl, onLogout: onLogout),
              const SizedBox(height: 22),
              _SectionHeader(
                title: s.storage,
                action: s.allFiles,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FileListScreen(ctrl: ctrl)),
                ),
              ),
              const SizedBox(height: 10),
              StorageCard(
                files: ctrl.files,
                onTotalTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FileListScreen(ctrl: ctrl)),
                ),
                onCategoryTap: (c) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FileListScreen(ctrl: ctrl, title: c.label, category: c),
                  ),
                ),
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionHeader(
                  title: s.recent,
                  action: s.allFiles,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FileListScreen(ctrl: ctrl)),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final f in recent.take(5))
                        FileTile(ctrl: ctrl, item: f),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: primary ? AppColors.primary : AppColors.cardHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 24,
                color: primary ? AppColors.onPrimary : AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(action, style: const TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }
}

class _ActiveDownloadsCard extends StatelessWidget {
  final DriveController ctrl;
  const _ActiveDownloadsCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final active = ctrl.downloads.tasks.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final progress = active
            .map((t) => t.size > 0 ? t.received / t.size : 0.0)
            .fold<double>(0, (a, b) => a + b) /
        active.length;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => showTransfers(context, ctrl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      active.length == 1
                          ? active.first.name
                          : context.s.downloadsActive(active.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WaveProgressBar(value: progress, height: 10),
              const SizedBox(height: 10),
              Text(
                context.s.savedToFolder,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
