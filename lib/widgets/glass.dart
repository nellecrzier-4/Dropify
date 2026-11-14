import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';


/// Panel kaca (glassmorphism): blur latar + lapisan transparan + border tipis.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 32,
    this.opacity = 0.07,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(opacity + 0.05),
                Colors.white.withOpacity(opacity - 0.02),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Latar berwarna dengan beberapa orb untuk efek kaca.
class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _GlassOrbPainter(t: _c.value),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GlassOrbPainter extends CustomPainter {
  _GlassOrbPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * 3.14159;
    _orb(canvas,
        Offset(size.width * (0.18 + 0.08 * math.sin(angle)),
            size.height * 0.16),
        size.width * 0.55,
        const Color(0xFF3D7BFF));
    _orb(canvas,
        Offset(size.width * (0.85 + 0.06 * math.cos(angle)),
            size.height * 0.42),
        size.width * 0.5,
        const Color(0xFF7B61FF));
    _orb(canvas,
        Offset(size.width * (0.45 + 0.1 * math.sin(angle + 1)),
            size.height * 0.88),
        size.width * 0.55,
        const Color(0xFF2BB6A6));
  }

  void _orb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.26), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassOrbPainter old) => old.t != t;
}
