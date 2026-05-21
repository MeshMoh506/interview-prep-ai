// lib/shared/widgets/background_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BackgroundPainter extends StatefulWidget {
  const BackgroundPainter({super.key});

  @override
  State<BackgroundPainter> createState() => _BackgroundPainterState();
}

class _BackgroundPainterState extends State<BackgroundPainter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter:
              _AmbientMeshPainter(progress: _controller.value, isDark: isDark),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AmbientMeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AmbientMeshPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final angle = progress * 2 * math.pi;

    // Fluid top right anchor
    final p1 = Offset(
      size.width * 0.8 + math.sin(angle) * 40,
      size.height * 0.1 + math.cos(angle) * 50,
    );
    paint.shader = RadialGradient(
      colors: [
        AppColors.violet.withValues(alpha: isDark ? 0.10 : 0.05),
        AppColors.violet.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: p1, radius: size.width * 0.7));
    canvas.drawCircle(p1, size.width * 0.7, paint);

    // Fluid mid left anchor
    final p2 = Offset(
      size.width * 0.1 + math.cos(angle) * 50,
      size.height * 0.5 + math.sin(angle) * 60,
    );
    paint.shader = RadialGradient(
      colors: [
        AppColors.cyan.withValues(alpha: isDark ? 0.08 : 0.04),
        AppColors.cyan.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: p2, radius: size.width * 0.6));
    canvas.drawCircle(p2, size.width * 0.6, paint);
  }

  @override
  bool shouldRepaint(_AmbientMeshPainter oldDelegate) => true;
}
