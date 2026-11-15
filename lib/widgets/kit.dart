import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// ---------------------------------------------------------------------------
/// Latar Material You: kanvas datar + wash tonal tipis dari skema aktif.
/// ---------------------------------------------------------------------------
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.intensity = 1,
    this.dots = false,
  });

  final Widget child;
  final bool animate;
  final double intensity;
  final bool dots;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: AppColors.bg),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _WashPainter(
                  t: widget.animate ? _c.value : 0.25,
                  intensity: widget.intensity,
                ),
              ),
            ),
          ),
          if (widget.dots)
            const Positioned.fill(child: IgnorePointer(child: DotGrid())),
          widget.child,
        ],
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  _WashPainter({required this.t, required this.intensity});

  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi;
    _blob(
      canvas,
      Offset(
        size.width * (0.12 + 0.06 * math.sin(angle)),
        size.height * (0.04 + 0.02 * math.cos(angle)),
      ),
      size.width * 0.85,
      AppColors.washA,
    );
    _blob(
      canvas,
      Offset(
        size.width * (0.92 + 0.05 * math.cos(angle + 1)),
        size.height * 0.28,
      ),
      size.width * 0.7,
      AppColors.washB,
    );
    _blob(
      canvas,
      Offset(
        size.width * (0.35 + 0.07 * math.sin(angle + 2)),
        size.height * 0.95,
      ),
      size.width * 0.9,
      AppColors.washC,
    );
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _WashPainter old) =>
      old.t != t || old.intensity != intensity;
}

/// Tekstur titik halus (menggantikan bayangan tebal pada panel tonal).
class DotGrid extends StatelessWidget {
  const DotGrid({
    super.key,
    this.spacing = 12,
    this.radius = 1.0,
    this.color,
  });

  final double spacing;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotPainter(
        spacing: spacing,
        radius: radius,
        color: color ??
            AppColors.scheme.onSurface.withValues(alpha: 0.05),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.spacing, required this.radius, required this.color});

  final double spacing;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.spacing != spacing || old.color != color || old.radius != radius;
}

/// ---------------------------------------------------------------------------
/// Permukaan M3 tonal.
/// ---------------------------------------------------------------------------
enum SurfaceElevation { none, sm, md, lg }

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadii.xl,
    this.elevation = SurfaceElevation.none,
    this.color,
    this.gradient,
    this.border = false,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final SurfaceElevation elevation;
  final Color? color;
  final Gradient? gradient;
  final bool border;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shadows = switch (elevation) {
      SurfaceElevation.none => const <BoxShadow>[],
      SurfaceElevation.sm => AppColors.shadowSm,
      SurfaceElevation.md => AppColors.shadowMd,
      SurfaceElevation.lg => AppColors.shadowLg,
    };

    final decoration = BoxDecoration(
      color: gradient == null
          ? (color ?? AppColors.scheme.surfaceContainerLow)
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border
          ? Border.all(color: AppColors.scheme.outlineVariant, width: 1)
          : null,
      boxShadow: shadows,
    );

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.scheme.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.scheme.primary.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: content,
            )
          : content,
    );
  }
}

/// Kaca M3: blur + lapisan surface container (dipakai untuk nav & sheet).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.radius = AppRadii.xl,
    this.blur = 28,
    this.opacity = 1,
    this.tint,
    this.border = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;
  final Color? tint;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ??
                AppColors.scheme.surfaceContainerHigh.withValues(
                  alpha: (dark ? 0.72 : 0.82) * opacity,
                ),
            borderRadius: BorderRadius.circular(radius),
            border: border
                ? Border.all(color: AppColors.scheme.outlineVariant)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Kartu tonal M3 ("tile" berwarna seperti di Material You).
class HeroSurface extends StatelessWidget {
  const HeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadii.xl,
    this.glow = false,
    this.onTap,
    this.color,
    this.foreground,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final VoidCallback? onTap;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final bg = color ?? scheme.primaryContainer;

    Widget content = Padding(padding: padding, child: child);

    content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor:
            (foreground ?? scheme.onPrimaryContainer).withValues(alpha: 0.08),
        child: content,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow ? AppColors.shadowMd : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Kotak ikon M3 (tonal container + ikon berwarna).
class GlowIcon extends StatelessWidget {
  const GlowIcon({
    super.key,
    required this.icon,
    this.size = 48,
    this.radius,
    this.color,
    this.iconSize,
    this.glow = false,
    this.filled = false,
    this.tinted = true,
  });

  final IconData icon;
  final double size;
  final double? radius;
  final Color? color;
  final double? iconSize;
  final bool glow;
  final bool filled;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final tint = color ?? scheme.onSecondaryContainer;
    final r = radius ?? size * 0.34;

    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.standard,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: filled
            ? tint
            : tinted
                ? tint.withValues(alpha: AppColors.isDark ? 0.20 : 0.12)
                : scheme.surfaceContainerHighest,
        boxShadow: glow ? AppColors.glow(tint, blur: 18, y: 6) : null,
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.46,
        color: filled ? AppColors.scheme.onPrimary : tint,
      ),
    );
  }
}

/// Orb besar untuk empty state / onboarding.
class OrbIcon extends StatelessWidget {
  const OrbIcon({
    super.key,
    required this.icon,
    this.size = 96,
    this.color,
    this.iconSize,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final tint = color ?? scheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: 0.14),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize ?? size * 0.34,
              color: tint,
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Tombol M3.
/// ---------------------------------------------------------------------------
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
    this.expand = true,
    this.tonal = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final bool expand;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final enabled = onPressed != null && !loading;
    final bg = tonal ? scheme.secondaryContainer : scheme.primary;
    final fg = tonal ? scheme.onSecondaryContainer : scheme.onPrimary;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: AnimatedScale(
        scale: enabled ? 1 : 0.99,
        duration: Motion.fast,
        child: Material(
          color: enabled
              ? bg
              : scheme.onSurface.withValues(alpha: 0.12),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    tapFeedback();
                    onPressed!.call();
                  }
                : null,
            splashColor: fg.withValues(alpha: 0.14),
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: loading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: fg,
                        ),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 19, color: fg),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              color: enabled
                                  ? fg
                                  : scheme.onSurface.withValues(alpha: 0.38),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  tapFeedback();
                  onPressed!.call();
                },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: scheme.onSurface),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip filter M3.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.color,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final tint = color ?? scheme.primary;
    final bg = selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    final chip = AnimatedContainer(
      duration: Motion.base,
      curve: Motion.spring,
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 14 : 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color != null && selected ? tint : fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Pressable(onTap: onTap, child: chip);
  }
}

/// Panel garis putus-putus untuk empty state.
class DashedPanel extends StatelessWidget {
  const DashedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadii.xl,
    this.color,
    this.dash = 6,
    this.gap = 5,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(
        radius: radius,
        color: color ??
            AppColors.scheme.outlineVariant.withValues(alpha: 0.9),
        dash: dash,
        gap: gap,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({
    required this.radius,
    required this.color,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap;
}

/// ---------------------------------------------------------------------------
/// Navigasi bawah M3 Expressive: item aktif melebar jadi pill berikon + label.
/// ---------------------------------------------------------------------------
class GlassNavItem {
  const GlassNavItem({required this.icon, required this.label, this.activeIcon});

  final IconData icon;
  final String label;
  final IconData? activeIcon;
}

class GlassNav extends StatelessWidget {
  const GlassNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    this.trailing,
  });

  final List<GlassNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    const barHeight = 56.0;
    const pad = 8.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppColors.shadowMd,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(
                alpha: AppColors.isDark ? 0.80 : 0.86,
              ),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trailingWidth = trailing == null ? 0.0 : 56.0;
                final usable = constraints.maxWidth - trailingWidth;
                final segment = usable / items.length;

                return SizedBox(
                  height: barHeight,
                  child: Stack(
                    children: [
                      // Indikator seleksi: lebar TETAP per segmen, hanya
                      // digeser — jadi bar tidak pernah berubah ukuran /
                      // bergoyang saat pindah tab.
                      AnimatedPositioned(
                        duration: Motion.slow,
                        curve: Motion.spring,
                        left: segment * index + 2,
                        top: 0,
                        bottom: 0,
                        width: segment - 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            SizedBox(
                              width: segment,
                              child: _NavItem(
                                item: items[i],
                                selected: i == index,
                                onTap: () => onTap(i),
                              ),
                            ),
                          if (trailing != null)
                            SizedBox(
                              width: trailingWidth,
                              child: Center(child: trailing),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Center(
        child: ClipRect(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0.94,
                duration: Motion.base,
                curve: Motion.spring,
                child: Icon(
                  selected ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 22,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              AnimatedSize(
                duration: Motion.slow,
                curve: Motion.spring,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox(width: 0, height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Judul kecil di atas grup.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, AppSpace.lg, 6, AppSpace.sm),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: AppColors.scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Baris statistik: ikon tonal + nilai + label.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.onPrimary = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.scheme;
    final valueColor =
        onPrimary ? scheme.onPrimaryContainer : scheme.onSurface;
    final labelColor = onPrimary
        ? scheme.onPrimaryContainer.withValues(alpha: 0.72)
        : scheme.onSurfaceVariant;

    return Row(
      children: [
        GlowIcon(
          icon: icon,
          size: 40,
          color: color ??
              (onPrimary ? scheme.onPrimaryContainer : scheme.primary),
          glow: false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: labelColor, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Snackbar standar aplikasi: mengapung di atas nav, bisa di-swipe kiri/kanan
/// atau ditutup lewat tombol X (penting untuk pesan error yang panjang).
void showAppSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 8),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      action: action,
      showCloseIcon: true,
      dismissDirection: DismissDirection.horizontal,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
  );
}
