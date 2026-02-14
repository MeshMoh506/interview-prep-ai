// lib/shared/widgets/custom_button.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool outlined;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.outlined = false,
    this.height = 52,
  });

  @override
  State<CustomButton> createState() => _S();
}

class _S extends State<CustomButton> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _sc;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _sc = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final bg = widget.backgroundColor ?? AppTheme.primary;
    final fg = widget.textColor ?? Colors.white;
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isLoading) _ac.forward();
      },
      onTapUp: (_) {
        _ac.reverse();
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
          scale: _sc,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            width: double.infinity,
            decoration: widget.outlined
                ? BoxDecoration(
                    border: Border.all(color: bg, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.transparent)
                : BoxDecoration(
                    color: widget.isLoading ? bg.withValues(alpha: 0.55) : bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: widget.isLoading
                        ? []
                        : [
                            BoxShadow(
                                color: bg.withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 6))
                          ]),
            child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: widget.outlined ? bg : fg))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              size: 18, color: widget.outlined ? bg : fg),
                          const SizedBox(width: 8),
                        ],
                        Text(widget.text,
                            style: TextStyle(
                                color: widget.outlined ? bg : fg,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.1)),
                      ])),
          )),
    );
  }
}
