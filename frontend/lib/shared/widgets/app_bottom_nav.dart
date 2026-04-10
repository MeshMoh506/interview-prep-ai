// lib/shared/widgets/app_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F1729).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.white.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.10),
                  blurRadius: 30,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
                if (!isDark)
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                _NavItem(
                    icon: Icons.home_rounded,
                    label: s.navHome,
                    index: 0,
                    current: currentIndex,
                    isDark: isDark,
                    onTap: () => _nav(context, '/home')),
                _NavItem(
                    icon: Icons.mic_rounded,
                    label: s.navInterview,
                    index: 1,
                    current: currentIndex,
                    isDark: isDark,
                    onTap: () => _nav(context, '/interview')),
                _CenterGoalItem(
                    label: s.navGoals,
                    index: 2,
                    current: currentIndex,
                    isDark: isDark,
                    onTap: () => _nav(context, '/goals')),
                _NavItem(
                    icon: Icons.description_rounded,
                    label: s.navResume,
                    index: 3,
                    current: currentIndex,
                    isDark: isDark,
                    onTap: () => _nav(context, '/resume')),
                _NavItem(
                    icon: Icons.person_rounded,
                    label: s.navProfile,
                    index: 4,
                    current: currentIndex,
                    isDark: isDark,
                    onTap: () => _nav(context, '/profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _nav(BuildContext context, String path) {
    HapticFeedback.lightImpact();
    context.go(path);
  }
}

// ── Standard nav item ─────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final bool isDark;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.index,
      required this.current,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final activeColor = AppColors.violet;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: isDark ? 0.18 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon,
                  color: selected ? activeColor : inactiveColor, size: 22),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              color: selected ? activeColor : inactiveColor,
              letterSpacing: 0.2,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ── Center Goals item — gradient pill with glow ───────────────────
class _CenterGoalItem extends StatelessWidget {
  final String label;
  final int index, current;
  final bool isDark;
  final VoidCallback onTap;
  const _CenterGoalItem(
      {required this.label,
      required this.index,
      required this.current,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = index == current;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: 52,
            height: 36,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              color: selected
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  Icons.flag_rounded,
                  color: selected
                      ? Colors.white
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.35)),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              color: selected
                  ? AppColors.violet
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35)),
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}
