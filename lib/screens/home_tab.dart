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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 28, 0, 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      );

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
          final initial =
              ctrl.username.isEmpty ? '?' : ctrl.username[0].toUpperCase();

          return RefreshIndicator(
            onRefresh: ctrl.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Icon(Icons.cloud, color: AppColors.logo, size: 38),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Dropify',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                    ListenableBuilder(
                      listenable: ctrl.downloads,
                      builder: (context, _) {
                        if (!ctrl.downloads.hasActive) {
                          return const SizedBox.shrink();
                        }
                        final active = ctrl.downloads.tasks
                            .where((t) => t.isActive)
                            .toList();
                        final progress = active.isEmpty
                            ? 0.0
                            : active
                                    .map((t) => t.progress)
                                    .reduce((a, b) => a + b) /
                                active.length;
                        final speed = active.fold<double>(
                          0,
                          (sum, t) => sum + t.speed,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Material(
                            color: AppColors.cardHigh,
                            shape: const StadiumBorder(),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => showTransfers(context, ctrl),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 2.4,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.divider,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      speed > 0
                                          ? '${formatSize(speed.round())}/s'
                                          : '…',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => showTransfers(context, ctrl),
                      icon: Badge(
                        isLabelVisible: ctrl.hasActiveTransfer,
                        child: const Icon(Icons.swap_vert,
                            color: AppColors.muted, size: 28),
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: AppColors.cardHigh,
                      onSelected: (v) {
                        if (v == 'logout') onLogout();
                        if (v == 'settings') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Text(ctrl.username.isEmpty
                              ? 'Pixeldrain'
                              : ctrl.username),
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
                        PopupMenuItem(
                          value: 'logout',
                          child: Text(s.logout),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.cardHigh,
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FileListScreen(ctrl: ctrl, search: true),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.muted),
                          const SizedBox(width: 16),
                          Text(s.searchHint,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 17)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: ctrl.downloads,
                  builder: (context, _) => ctrl.downloads.hasActive
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ActiveDownloadsCard(ctrl: ctrl),
                        )
                      : const SizedBox.shrink(),
                ),
                SyncCard(ctrl: ctrl, onLogout: onLogout),
                _label(s.storage),
                StorageCard(
                  files: ctrl.files,
                  onTotalTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FileListScreen(ctrl: ctrl)),
                  ),
                  onCategoryTap: (c) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FileListScreen(
                          ctrl: ctrl, title: c.label, category: c),
                    ),
                  ),
                ),
                if (recent.isNotEmpty) ...[
                  _label(s.recent),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
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
            ),
          );
        },
      ),
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
