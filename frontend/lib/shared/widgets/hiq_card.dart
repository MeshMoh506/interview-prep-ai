import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class HiqCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  const HiqCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorder = borderColor ??
        (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final r = borderRadius ?? AppTheme.radiusLg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: effectiveBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HiqHeroBanner extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final Color? borderColor;

  const HiqHeroBanner({
    super.key,
    required this.child,
    this.colors,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? (isDark
              ? [const Color(0xFF1A1228), const Color(0xFF0D1A2A)]
              : [const Color(0xFFEEE8FF), const Color(0xFFE0F5FF)]),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: borderColor ?? (isDark
              ? const Color(0x40734FFF)
              : const Color(0x307C5CFC)),
        ),
      ),
      child: child,
    );
  }
}

class ScorePill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;

  const ScorePill({
    super.key,
    required this.label,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
