import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Garis progres bergelombang ala Material Expressive.
///
/// Dipakai untuk progres download supaya pergerakannya terasa hidup tanpa
/// perlu gambar atau aset tambahan.
class WaveProgressBar extends StatefulWidget {
  const WaveProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color,
    this.trackColor,
    this.animate = true,
    this.indeterminate = false,
  });

  /// 0..1
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final bool animate;
  final bool indeterminate;

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
            progress: widget.indeterminate ? 0.4 : widget.value.clamp(0.0, 1.0),
            phase: _controller.value * 2 * math.pi,
            color: widget.color ?? AppColors.primary,
            trackColor: widget.trackColor ?? AppColors.divider,
            indeterminate: widget.indeterminate,
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
  });

  final double progress;
  final double phase;
  final Color color;
  final Color trackColor;
  final bool indeterminate;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final centerY = size.height / 2;
    final start = h * 0.5;
    final end = size.width - h * 0.5;
    if (end <= start) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = h * 0.34
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(start, centerY), Offset(end, centerY), trackPaint);

    if (indeterminate) {
      _drawSegment(canvas, size, start, end, phase);
      return;
    }

    if (progress <= 0) return;
    final stop = start + (end - start) * progress;
    _drawSegment(canvas, size, start, stop, phase);
  }

  void _drawSegment(
    Canvas canvas,
    Size size,
    double from,
    double to,
    double phase,
  ) {
    if (to - from <= 0.5) return;
    final h = size.height;
    final centerY = size.height / 2;
    final amplitude = h * 0.30;
    final path = Path()..moveTo(from, centerY);

    const steps = 64;
    for (var i = 1; i <= steps; i++) {
      final x = from + (to - from) * i / steps;
      final y = centerY +
          math.sin((x / math.max(size.width, 1)) * 8 * math.pi + phase) *
              amplitude;
      path.lineTo(x, y);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = h * 0.92
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.indeterminate != indeterminate;
}
