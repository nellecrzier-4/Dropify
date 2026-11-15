import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kit.dart';

/// Kotak kerangka dengan sapuan cahaya, dipakai saat data pertama dimuat.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final base = scheme.surfaceContainerHigh;
    final highlight = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final t = _sweep.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.6 + 3.2 * t, 0),
              end: Alignment(-0.6 + 3.2 * t, 0),
              colors: [
              AppColors.scheme.surfaceContainerLow,
              highlight,
              AppColors.scheme.surfaceContainerLow,
            ],
              stops: const [0.0, 0.5, 1.0],
            ),
            color: base,
          ),
        );
      },
    );
  }
}

/// Kerangka kartu penyimpanan + daftar berkas terakhir untuk HomeTab.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Surface(
          radius: AppRadii.xl,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(height: 12, width: 90, radius: 8),
              SizedBox(height: 12),
              SkeletonBox(height: 30, width: 150, radius: 10),
              SizedBox(height: 14),
              SkeletonBox(height: 8, radius: 99),
              SizedBox(height: 10),
              SkeletonBox(height: 12, width: 120, radius: 8),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SkeletonBox(height: 14, width: 80, radius: 8),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++) ...[
          Row(
            children: [
              const SkeletonBox(height: 44, width: 44, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 12, radius: 8),
                    SizedBox(height: 8),
                    SkeletonBox(height: 10, width: 90, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
