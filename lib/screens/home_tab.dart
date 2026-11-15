import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../screens/settings_screen.dart';
import 'gofile_screen.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_tile.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
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
          final initial =
              ctrl.username.isEmpty ? '?' : ctrl.username[0].toUpperCase();
          var step = 0;
          Widget stagger(Widget child) =>
              Stagger(index: step++, child: child);

          return RefreshIndicator(
            onRefresh: ctrl.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                stagger(
                  _Header(
                    ctrl: ctrl,
                    initial: initial,
                    onLogout: onLogout,
                    onSettings: () => Navigator.push(
                      context,
                      SharedAxisPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                stagger(
                  _SearchBar(
                    hint: s.searchHint,
                    onTap: () => Navigator.push(
                      context,
                      SharedAxisPageRoute(
                        builder: (_) =>
                            FileListScreen(ctrl: ctrl, search: true),
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: ctrl.downloads,
                  builder: (context, _) => AnimatedSize(
                    duration: Motion.base,
                    curve: Motion.emphasized,
                    alignment: Alignment.topCenter,
                    child: !ctrl.downloads.hasActive
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _ActiveDownloadsCard(ctrl: ctrl),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                stagger(SyncCard(ctrl: ctrl, onLogout: onLogout)),
                stagger(SectionLabel(s.storage)),
                stagger(
                  StorageCard(
                    files: ctrl.files,
                    onTotalTap: () => Navigator.push(
                      context,
                      SharedAxisPageRoute(
                          builder: (_) => FileListScreen(ctrl: ctrl)),
                    ),
                    onCategoryTap: (c) => Navigator.push(
                      context,
                      SharedAxisPageRoute(
                        builder: (_) =>
                            FileListScreen(ctrl: ctrl, title: c.label(s), category: c),
                      ),
                    ),
                  ),
                ),
                if (recent.isNotEmpty) ...[
                  stagger(SectionLabel(s.recent)),
                  for (final f in recent.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FileTile(ctrl: ctrl, item: f, index: step++),
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

/// Kolom pencarian M3 (search bar): permukaan tonal tinggi, sudut pill.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: false,
      child: Surface(
        radius: AppRadii.pill,
        color: AppColors.scheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: AppColors.scheme.onSurfaceVariant, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.scheme.onSurfaceVariant,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris atas: tanda merek, pill transfer aktif, tombol transfer, dan menu akun.
class _Header extends StatelessWidget {
  const _Header({
    required this.ctrl,
    required this.initial,
    required this.onLogout,
    required this.onSettings,
  });

  final DriveController ctrl;
  final String initial;
  final VoidCallback onLogout;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = AppColors.scheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            boxShadow: AppColors.glow(scheme.primary, blur: 16, y: 6),
          ),
          child: Icon(Icons.cloud_rounded, size: 23, color: scheme.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (ctrl.username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  ctrl.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        ListenableBuilder(
          listenable: ctrl.downloads,
          builder: (context, _) {
            if (!ctrl.downloads.hasActive) return const SizedBox.shrink();
            final active =
                ctrl.downloads.tasks.where((t) => t.isActive).toList();
            final progress = active.isEmpty
                ? 0.0
                : active.map((t) => t.progress).reduce((a, b) => a + b) /
                    active.length;
            final speed = active.fold<double>(0, (sum, t) => sum + t.speed);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _TransferPill(
                progress: progress,
                label: speed > 0 ? '${formatSize(speed.round())}/s' : '…',
                onTap: () => showTransfers(context, ctrl),
              ),
            );
          },
        ),
        Badge(
          isLabelVisible: ctrl.hasActiveTransfer,
          smallSize: 9,
          backgroundColor: scheme.primary,
          child: IconButton.filledTonal(
            tooltip: s.transfers,
            onPressed: () {
              tapFeedback();
              showTransfers(context, ctrl);
            },
            icon: Icon(Icons.swap_vert_rounded, size: 21),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          offset: const Offset(0, 52),
          color: AppColors.cardHigh,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          onSelected: (v) {
            if (v == 'logout') onLogout();
            if (v == 'settings') onSettings();
            if (v == 'gofile') {
              Navigator.of(context).push(
                SharedAxisPageRoute<void>(
                  builder: (_) => const GofileScreen(),
                ),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                ctrl.username.isEmpty ? 'Pixeldrain' : ctrl.username,
                style: TextStyle(
                  color: AppColors.scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'gofile',
              child: Row(
                children: [
                  Icon(Icons.folder_shared_rounded,
                      size: 18, color: AppColors.scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Text('Gofile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.scheme.onSurfaceVariant),
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
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer,
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill kecil berisi cincin progres + kecepatan gabungan.
class _TransferPill extends StatelessWidget {
  const _TransferPill({
    required this.progress,
    required this.label,
    required this.onTap,
  });

  final double progress;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.emphasized,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Motion.emphasized,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 2.4,
                  color: scheme.onPrimaryContainer,
                  backgroundColor:
                      scheme.onPrimaryContainer.withValues(alpha: 0.18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
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
    final scheme = AppColors.scheme;

    return Surface(
      radius: AppRadii.xl,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => showTransfers(context, ctrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIcon(
                icon: Icons.downloading_rounded,
                size: 40,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    active.length == 1
                        ? active.first.name
                        : context.s.downloadsActive(active.length),
                    key: ValueKey(active.length == 1
                        ? active.first.name
                        : 'n${active.length}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Motion.emphasized,
                builder: (context, value, _) => Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WaveProgressBar(value: progress, height: 9),
          const SizedBox(height: 9),
          Text(
            context.s.savedToFolder,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
