import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lingkaran berombak (scalloped) dengan ikon di tengah — elemen utama layar
/// setup/login, mengikuti referensi desain.
class StarBadge extends StatelessWidget {
  const StarBadge({
    super.key,
    required this.icon,
    this.size = 180,
    this.color,
    this.iconColor = const Color(0xFFD3DDFF),
    this.lobes = 12,
    this.iconScale = 0.42,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color iconColor;
  final int lobes;
  final double iconScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScallopPainter(color: color ?? AppColors.accent, lobes: lobes),
        child: Center(
          child: Icon(icon, size: size * iconScale, color: iconColor),
        ),
      ),
    );
  }
}

class _ScallopPainter extends CustomPainter {
  _ScallopPainter({required this.color, required this.lobes});

  final Color color;
  final int lobes;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    const steps = 360;

    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final r = radius * (0.90 + 0.10 * math.cos(lobes * t));
      final point = Offset(
        center.dx + r * math.cos(t),
        center.dy + r * math.sin(t),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScallopPainter old) =>
      old.color != color || old.lobes != lobes;
}
