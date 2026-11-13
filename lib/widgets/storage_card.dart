import 'dart:math';

import 'package:flutter/material.dart';

import '../models/pd_item.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';
import '../utils/file_types.dart';

class _Stat {
  final FileCategory category;
  int count = 0;
  int size = 0;
  _Stat(this.category);
}

/// Ringkasan storage dihitung dari file asli di Pixeldrain.
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTotalTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(formatSize(total),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(context.s.inFiles(files.length),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 16)),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.muted, size: 22),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SegmentBar(stats: visible, total: total),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
              child: Text(context.s.noFilesYet,
                  style: const TextStyle(color: AppColors.muted)),
            ),
          for (final s in visible) ...[
            Divider(height: 1, thickness: 1, color: AppColors.divider),
            InkWell(
              onTap: () => onCategoryTap(s.category),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Row(
                  children: [
                    Icon(s.category.icon, color: s.category.color, size: 28),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(s.category.label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                    ),
                    Text(
                        '${s.category.countLabel(s.count)} · ${formatSize(s.size)}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 15)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: AppColors.muted, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final List<_Stat> stats;
  final int total;
  const _SegmentBar({required this.stats, required this.total});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final parts = stats.where((s) => s.size > 0).toList();
      Widget track(Widget? child) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              color: AppColors.divider,
              child: child,
            ),
          );
      if (parts.isEmpty || total == 0) return track(null);

      const gap = 3.0;
      const minW = 5.0;
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
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Container(
                  width: widths[i], height: 8, color: parts[i].category.color),
            ],
          ],
        ),
      );
    });
  }
}
