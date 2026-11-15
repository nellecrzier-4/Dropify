import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../models/pd_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';
import 'kit.dart';
import 'motion.dart';

class _Stat {
  final FileCategory category;
  int count = 0;
  int size = 0;
  _Stat(this.category);
}

/// Ringkasan storage dihitung dari file asli di Pixeldrain.
///
/// Tampil sebagai kartu tonal Material You ([HeroSurface] = primaryContainer):
/// ukuran total besar (animasi [AnimatedCount]), jumlah file, bar kategori
/// bersegment, lalu chip per kategori — semuanya memakai onPrimaryContainer.
class StorageCard extends StatelessWidget {
  final List<PdItem> files;
  final VoidCallback onTotalTap;
  final void Function(FileCategory) onCategoryTap;

  const StorageCard({
    super.key,
    required this.files,
    required this.onTotalTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = {for (final c in FileCategory.values) c: _Stat(c)};
    var total = 0;
    for (final f in files) {
      final s = stats[f.category]!;
      s.count++;
      s.size += f.size;
      total += f.size;
    }
    final visible = stats.values.where((s) => s.count > 0).toList();
    final onTint = AppColors.scheme.onPrimaryContainer;

    return HeroSurface(
      radius: AppRadii.xl,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              tapFeedback();
              onTotalTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AnimatedCount(
                          value: total,
                          format: (v) => formatSize(v.round()),
                          style: TextStyle(
                            color: onTint,
                            fontSize: 34,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: onTint.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.s.inFiles(files.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onTint.withValues(alpha: 0.74),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SegmentBar(
                    stats: visible,
                    total: total,
                    onTap: onTotalTap,
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.s.noFilesYet,
                  style: TextStyle(
                    color: onTint.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                ),
              ),
            )
          else
            // Kategori ringkas: chip yang membungkus, jadi tidak ada label
            // yang terpotong di tepi kartu.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    Stagger(
                      index: i,
                      child: _HeroChip(
                        stat: visible[i],
                        onTap: () => onCategoryTap(visible[i].category),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip kategori ringkas di dalam kartu tonal.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.stat, required this.onTap});

  final _Stat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onTint = AppColors.scheme.onPrimaryContainer;
    final tint = chipColor(stat.category.color);
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: onTint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stat.category.icon, size: 15, color: tint),
            const SizedBox(width: 7),
            Text(
              '${stat.category.label(context.s)} · ${formatSize(stat.size)}',
              style: TextStyle(
                color: onTint,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Warna kategori yang "duduk" di atas primaryContainer: digeser ke arah
/// onPrimaryContainer (menggelap di tema terang, menerang di tema gelap).
Color chipColor(Color c) =>
    Color.lerp(c, AppColors.scheme.onPrimaryContainer, 0.30)!;

/// Warna batang kategori — versi lebih pekat dari [chipColor].
Color barColor(Color c) => Color.lerp(
      c,
      AppColors.scheme.onPrimaryContainer,
      AppColors.isDark ? 0.10 : 0.22,
    )!;

class _SegmentBar extends StatelessWidget {
  final List<_Stat> stats;
  final int total;
  final VoidCallback onTap;
  const _SegmentBar({
    required this.stats,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onTint = AppColors.scheme.onPrimaryContainer;
    final trackColor = onTint.withValues(alpha: 0.12);
    return LayoutBuilder(builder: (context, box) {
      final parts = stats.where((s) => s.size > 0).toList();
      Widget track(Widget? child) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 10,
              color: trackColor,
              child: child,
            ),
          );
      if (parts.isEmpty || total == 0) return track(null);

      const gap = 3.0;
      const minW = 6.0;
      final avail = box.maxWidth - gap * (parts.length - 1);
      final widths =
          parts.map((s) => max(minW, avail * s.size / total)).toList();
      final sum = widths.fold<double>(0, (a, b) => a + b);
      if (sum > avail) {
        var big = 0;
        for (var i = 1; i < widths.length; i++) {
          if (widths[i] > widths[big]) big = i;
        }
        widths[big] -= (sum - avail);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          height: 10,
          child: Row(
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                AnimatedContainer(
                  duration: Motion.slow,
                  curve: Motion.emphasized,
                  width: widths[i],
                  height: 10,
                  decoration: BoxDecoration(
                    color: barColor(parts[i].category.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
