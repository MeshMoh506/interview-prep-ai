// lib/shared/widgets/theme_toggle_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_colors.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggle(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 48,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          // Dark mode: subtle white border track
          // Light mode: solid violet track so it's clearly visible
          color:
              isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.violet,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : AppColors.violet,
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 12,
                // Icon color contrasts against white circle
                color: isDark ? const Color(0xFF1E293B) : AppColors.violet,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
