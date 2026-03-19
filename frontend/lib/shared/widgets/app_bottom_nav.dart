// lib/shared/widgets/app_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/locale/app_strings.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavEntry(
                  icon: Icons.home_rounded,
                  label: s.navHome,
                  isSelected: currentIndex == 0,
                  onTap: () => context.go('/home'),
                  isDark: isDark,
                ),
                _NavEntry(
                  icon: Icons.mic_rounded,
                  label: s.navInterview,
                  isSelected: currentIndex == 1,
                  onTap: () => context.go('/interview'),
                  isDark: isDark,
                ),
                _NavEntry(
                  icon: Icons.description_rounded,
                  label: s.navResume,
                  isSelected: currentIndex == 2,
                  onTap: () => context.go('/resume'),
                  isDark: isDark,
                ),
                _NavEntry(
                  icon: Icons.route_rounded,
                  label: s.navRoadmap,
                  isSelected: currentIndex == 3,
                  onTap: () => context.go('/roadmap'),
                  isDark: isDark,
                ),
                _NavEntry(
                  icon: Icons.person_rounded,
                  label: s.navProfile,
                  isSelected: currentIndex == 4,
                  onTap: () => context.go('/profile'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavEntry({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.violet;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
