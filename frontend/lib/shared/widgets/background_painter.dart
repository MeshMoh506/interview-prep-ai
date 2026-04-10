// lib/shared/widgets/background_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BackgroundPainter extends StatefulWidget {
  const BackgroundPainter({super.key});
  @override
  State<BackgroundPainter> createState() => BackgroundPainterState();
}

class BackgroundPainterState extends State<BackgroundPainter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _BlobPainter(progress: _anim.value, isDark: isDark),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _BlobPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Blob 1 — violet top-right, larger & richer
    canvas.drawCircle(
      Offset(
        size.width * (0.75 + 0.08 * math.sin(progress * math.pi)),
        size.height * (0.08 + 0.06 * math.cos(progress * math.pi)),
      ),
      size.width * 0.52,
      Paint()
        ..color = AppColors.violet.withValues(alpha: isDark ? 0.22 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );

    // Blob 2 — cyan bottom-left
    canvas.drawCircle(
      Offset(
        size.width * (0.08 + 0.07 * math.cos(progress * math.pi)),
        size.height * (0.78 + 0.07 * math.sin(progress * math.pi)),
      ),
      size.width * 0.48,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: isDark ? 0.14 : 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100),
    );

    // Blob 3 — emerald center — subtle depth
    canvas.drawCircle(
      Offset(
        size.width * (0.5 + 0.06 * math.sin(progress * math.pi * 1.3)),
        size.height * (0.45 + 0.05 * math.cos(progress * math.pi * 0.8)),
      ),
      size.width * 0.30,
      Paint()
        ..color = AppColors.emerald.withValues(alpha: isDark ? 0.06 : 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.progress != progress;
}
