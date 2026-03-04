// lib/shared/widgets/background_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated gradient background with floating color blobs.
/// Used on auth screens AND the home screen.
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
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
          painter: _BlobPainter(
            progress: _anim.value,
            isDark: isDark,
          ),
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
    // Blob 1 — violet top-right
    final p1 = Paint()
      ..color = AppColors.violet.withValues(alpha: isDark ? 0.18 : 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final offset1 = Offset(
      size.width * (0.7 + 0.1 * math.sin(progress * math.pi)),
      size.height * (0.1 + 0.05 * math.cos(progress * math.pi)),
    );
    canvas.drawCircle(offset1, size.width * 0.45, p1);

    // Blob 2 — blue bottom-left
    final p2 = Paint()
      ..color = AppColors.cyan.withValues(alpha: isDark ? 0.12 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final offset2 = Offset(
      size.width * (0.1 + 0.08 * math.cos(progress * math.pi)),
      size.height * (0.75 + 0.08 * math.sin(progress * math.pi)),
    );
    canvas.drawCircle(offset2, size.width * 0.5, p2);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.progress != progress;
}
