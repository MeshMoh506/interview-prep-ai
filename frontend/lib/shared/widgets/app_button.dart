import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant   = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  Widget _child() => isLoading
      ? SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: variant == AppButtonVariant.primary
                ? Colors.white
                : AppColors.violet,
          ),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        );

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return SizedBox(
          width: width ?? double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: _child(),
          ),
        );
      case AppButtonVariant.outline:
        return SizedBox(
          width: width ?? double.infinity,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: _child(),
          ),
        );
      case AppButtonVariant.ghost:
        return SizedBox(
          width: width ?? double.infinity,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            child: _child(),
          ),
        );
      case AppButtonVariant.danger:
        return SizedBox(
          width: width ?? double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: _child(),
          ),
        );
    }
  }
}
