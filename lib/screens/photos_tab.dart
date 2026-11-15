import 'package:flutter/material.dart';

import '../controllers/drive_controller.dart';
import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import '../widgets/file_actions.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

class PhotosTab extends StatelessWidget {
  final DriveController ctrl;
  const PhotosTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final photos = ctrl.files
              .where((f) =>
                  f.category == FileCategory.images ||
                  f.mime.toLowerCase().startsWith('image/'))
              .toList()
            ..sort((a, b) =>
                (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.s.photos,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (photos.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Stagger(
                        index: 1,
                        child: SoftChip(
                          icon: Icons.photo_library_outlined,
                          label: '${photos.length}',
                          color: AppColors.images,
                          selected: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: AnimatedSwitcher(
                    duration: Motion.slow,
                    switchInCurve: Motion.emphasized,
                    switchOutCurve: Motion.standard,
                    child: photos.isEmpty
                        ? ListView(
                            key: const ValueKey('empty'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                            children: [const _EmptyPhotos()],
                          )
                        : GridView.builder(
                            key: const ValueKey('grid'),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                            itemCount: photos.length,
                            itemBuilder: (_, i) {
                              final p = photos[i];
                              return Stagger(
                                index: i,
                                step: const Duration(milliseconds: 35),
                                slide: 12,
                                child: _PhotoTile(
                                  controller: ctrl,
                                  item: p,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Satu foto dalam grid: kartu tonal bersudut 24 + gambar yang memudar masuk.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.controller, required this.item});

  final DriveController controller;
  final PdItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return Pressable(
      onTap: () => downloadItem(context, controller, item),
      onLongPress: () => showItemActions(context, controller, item),
      scale: 0.95,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Image.network(
            item.thumbnailUrl,
            headers: controller.api.authHeaders,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: Motion.slow,
                curve: Motion.standard,
                child: child,
              );
            },
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state foto: panel bergaris putus + orb ikon.
class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos();

  @override
  Widget build(BuildContext context) {
    return Stagger(
      child: DashedPanel(
        radius: AppRadii.xl,
        padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
        child: Column(
          children: [
            OrbIcon(
              icon: Icons.photo_library_outlined,
              size: 106,
              color: AppColors.images,
            ),
            const SizedBox(height: 18),
            Text(
              context.s.noPhotos,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
