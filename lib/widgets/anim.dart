import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Muncul dengan fade + naik + membesar, bisa diberi jeda untuk efek stagger.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slide = 24,
    this.duration = const Duration(milliseconds: 620),
    this.scaleFrom = 0.96,
  });

  final Widget child;
  final Duration delay;
  final double slide;
  final Duration duration;
  final double scaleFrom;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.slide),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Napas halus untuk badge/ikon besar.
class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.child,
    this.scale = 0.025,
    this.period = const Duration(seconds: 4),
  });

  final Widget child;
  final double scale;
  final Duration period;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1 + widget.scale * Curves.easeInOut.transform(_controller.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Efek tombol mengecil saat ditekan.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.pressedScale = 0.97});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Latar dengan dua "orb" gradien yang bergerak pelan.
class OrbBackground extends StatefulWidget {
  const OrbBackground({super.key, required this.child});

  final Widget child;

  @override
  State<OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<OrbBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _OrbPainter(t: _controller.value),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi;

    _orb(
      canvas,
      center: Offset(
        size.width * (0.28 + 0.10 * math.sin(angle)),
        size.height * 0.10 + size.height * 0.05 * math.cos(angle),
      ),
      radius: size.width * 0.62,
      color: AppColors.accent.withOpacity(0.33),
    );

    _orb(
      canvas,
      center: Offset(
        size.width * (0.80 + 0.08 * math.cos(angle * 0.8)),
        size.height * 0.30 + size.height * 0.06 * math.sin(angle * 0.7),
      ),
      radius: size.width * 0.45,
      color: const Color(0xFF5B4BE8).withOpacity(0.18),
    );
  }

  void _orb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => old.t != t;
}
