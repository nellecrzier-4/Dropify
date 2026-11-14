import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_actions.dart';
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

          final categories = <FileCategory, List<PdItem>>{};
          for (final f in ctrl.files) {
            categories.putIfAbsent(f.category, () => []).add(f);
          }

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 360,
                child: _Hero(
                  initial: initial,
                  username: ctrl.username,
                  total: formatSize(total),
                  count: ctrl.files.length,
                  onSettings: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                  onLogout: onLogout,
                ),
              ),
              Positioned.fill(
                child: ListView(
                  padding: const EdgeInsets.only(top: 322, bottom: 130),
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(34)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.bg.withOpacity(0.82),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(34)),
                            border: Border(
                              top: BorderSide(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(50),
                                      ),
                                      onPressed: () {
                                        showTransfers(context, ctrl,
                                            initialTab: 1);
                                        ctrl.pickAndUpload();
                                      },
                                      icon: const Icon(
                                          Icons.upload_file_rounded,
                                          size: 20),
                                      label: Text(s.uploadFile),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(50),
                                        foregroundColor: AppColors.text,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withOpacity(0.16)),
                                        shape: const StadiumBorder(),
                                      ),
                                      onPressed: () =>
                                          showTransfers(context, ctrl),
                                      icon: const Icon(Icons.link_rounded,
                                          size: 20),
                                      label: Text(s.download),
                                    ),
                                  ),
                                ],
                              ),
                              ListenableBuilder(
                                listenable: ctrl.downloads,
                                builder: (context, _) =>
                                    ctrl.downloads.hasActive
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.only(top: 16),
                                            child:
                                                _ActiveDownloadsCard(ctrl: ctrl),
                                          )
                                        : const SizedBox.shrink(),
                              ),
                              if (recent.isNotEmpty)
                                _Shelf(
                                  title: s.recent,
                                  action: s.allFiles,
                                  onMore: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            FileListScreen(ctrl: ctrl)),
                                  ),
                                  children: [
                                    for (final f in recent.take(10))
                                      _ArtCard(
                                        title: f.name,
                                        subtitle: formatSize(f.size),
                                        icon: f.category.icon,
                                        color: f.category.color,
                                        onTap: () =>
                                            downloadItem(context, ctrl, f),
                                        onLongPress: () => showItemActions(
                                            context, ctrl, f),
                                      ),
                                  ],
                                ),
                              if (categories.isNotEmpty)
                                _Shelf(
                                  title: s.storage,
                                  action: s.allFiles,
                                  onMore: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            FileListScreen(ctrl: ctrl)),
                                  ),
                                  children: [
                                    for (final entry in categories.entries)
                                      _ArtCard(
                                        title: entry.key.label,
                                        subtitle:
                                            '${entry.value.length} ${s.files.toLowerCase()}',
                                        icon: entry.key.icon,
                                        color: entry.key.color,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FileListScreen(
                                              ctrl: ctrl,
                                              title: entry.key.label,
                                              category: entry.key,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              const SizedBox(height: 22),
                              SyncCard(ctrl: ctrl, onLogout: onLogout),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.children,
    required this.action,
    required this.onMore,
  });

  final String title;
  final List<Widget> children;
  final String action;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}

class _ArtCard extends StatelessWidget {
  const _ArtCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 172,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.32),
                    color.withOpacity(0.08),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(icon, size: 54, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
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


class _Hero extends StatelessWidget {
  const _Hero({
    required this.initial,
    required this.username,
    required this.total,
    required this.count,
    required this.onSettings,
    required this.onLogout,
  });

  final String initial;
  final String username;
  final String total;
  final int count;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.accent, AppColors.bg, 0.35)!,
            Color.lerp(AppColors.accent, AppColors.bg, 0.75)!,
            AppColors.bg,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: 40,
            child: Icon(
              Icons.cloud_rounded,
              size: 240,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.cloud_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text('Dropify',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const Spacer(),
                      PopupMenuButton<String>(
                        color: AppColors.cardHigh,
                        onSelected: (v) {
                          if (v == 'logout') onLogout();
                          if (v == 'settings') onSettings();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Text(username.isEmpty ? 'Pixeldrain' : username),
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
                              value: 'logout', child: Text(s.logout)),
                        ],
                        child: CircleAvatar(
                          radius: 21,
                          backgroundColor: Colors.white.withOpacity(0.16),
                          child: Text(initial,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    total,
                    style: const TextStyle(
                      fontSize: 48,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count ${s.files.toLowerCase()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
