import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Progress "squiggle" ala Material 3 Expressive.
///
/// Garis bergelombang yang bergerak terus; amplitude-nya berdenyut pelan supaya
/// terasa hidup. Bisa determinate ([value]) atau indeterminate
/// ([indeterminate]) yang berjalan dari kiri ke kanan.
class WaveProgressBar extends StatefulWidget {
  const WaveProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color,
    this.trackColor,
    this.animate = true,
    this.indeterminate = false,
    this.waves,
  });

  /// 0..1
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final bool animate;
  final bool indeterminate;

  /// Jumlah gelombang sepanjang bar. Default mengikuti lebar.
  final int? waves;

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WavePainter(
            progress: widget.value.clamp(0.0, 1.0),
            phase: _controller.value * 2 * math.pi,
            color: widget.color ?? AppColors.scheme.primary,
            trackColor:
                widget.trackColor ?? AppColors.scheme.surfaceContainerHighest,
            indeterminate: widget.indeterminate,
            waves: widget.waves,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.indeterminate,
    this.waves,
  });

  final double progress;
  final double phase;
  final Color color;
  final Color trackColor;
  final bool indeterminate;
  final int? waves;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final centerY = h / 2;
    final start = h * 0.5;
    final end = size.width - h * 0.5;
    if (end <= start) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = math.max(3, h * 0.30)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(start, centerY), Offset(end, centerY), trackPaint);

    // Amplitude berdenyut pelan supaya squiggle "bernapas".
    final breathe = 0.78 + 0.22 * math.sin(phase * 0.5);
    final amplitude = h * 0.22 * breathe;
    final count = waves ?? math.max(3, (size.width / 54).round());

    if (indeterminate) {
      // Satu bentang gelombang yang berjalan, dengan ujung memudar.
      final span = (end - start) * 0.34;
      final travel = (end - start) - span;
      final t = (phase / (2 * math.pi)) % 1.0;
      final from = start + travel * t;
      _stroke(
        canvas,
        _squiggle(from, from + span, centerY, amplitude, count, phase, size),
        math.max(3.5, h * 0.45),
        color,
      );
      return;
    }

    if (progress <= 0.001) return;

    final stop = start + (end - start) * progress;
    final path = _squiggle(start, stop, centerY, amplitude, count, phase, size);
    _stroke(canvas, path, math.max(3.5, h * 0.45), color);
  }

  Path _squiggle(
    double from,
    double to,
    double centerY,
    double amplitude,
    int count,
    double phase,
    Size size,
  ) {
    final path = Path()..moveTo(from, centerY);
    const steps = 96;
    final span = to - from;
    for (var i = 1; i <= steps; i++) {
      final p = i / steps;
      final x = from + span * p;
      final y = centerY +
          math.sin(p * count * 2 * math.pi + phase) *
              amplitude *
              math.sin(math.pi * p * 0.5 + 0.001).clamp(0.0, 1.0);
      path.lineTo(x, y);
    }
    // Ujung bulat: kembali lewat garis tengah supaya tutupnya rapi.
    path.lineTo(to, centerY);
    return path;
  }

  void _stroke(Canvas canvas, Path path, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.indeterminate != indeterminate ||
      old.waves != waves;
}
