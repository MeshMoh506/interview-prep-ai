// lib/shared/widgets/app_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/locale/app_strings.dart';

// ── Index map ────────────────────────────────────────────────────
//  0 = Home       /home
//  1 = Interview  /interview
//  2 = Goals      /goals      ← island LEFT  (violet when active)
//  3 = Practice   /practice   ← island RIGHT (violet when active)
//  4 = Resume     /resume
//  5 = Profile    /profile

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    final bg = isDark ? const Color(0xFF1A1D26) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: isDark ? 0.88 : 0.94),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            if (isDark)
              BoxShadow(
                  color: Colors.white.withValues(alpha: 0.03),
                  blurRadius: 2,
                  spreadRadius: 1),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Row(children: [
              _Tab(
                  icon: Icons.home_rounded,
                  label: s.navHome,
                  idx: 0,
                  cur: currentIndex,
                  isDark: isDark,
                  onTap: () => _go(context, '/home')),
              _Tab(
                  icon: Icons.mic_rounded,
                  label: s.navInterview,
                  idx: 1,
                  cur: currentIndex,
                  isDark: isDark,
                  onTap: () => _go(context, '/interview')),
              _Island(
                labelLeft: s.navGoals,
                labelRight: s.navCoach,
                idxLeft: 2,
                idxRight: 3,
                cur: currentIndex,
                isDark: isDark,
                onLeft: () => _go(context, '/goals'),
                onRight: () => _go(context, '/coach'),
              ),
              _Tab(
                  icon: Icons.description_rounded,
                  label: s.navResume,
                  idx: 4,
                  cur: currentIndex,
                  isDark: isDark,
                  onTap: () => _go(context, '/resume')),
              _Tab(
                  icon: Icons.person_rounded,
                  label: s.navProfile,
                  idx: 5,
                  cur: currentIndex,
                  isDark: isDark,
                  onTap: () => _go(context, '/profile')),
            ]),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    HapticFeedback.lightImpact();
    context.go(path);
  }
}

// ══════════════════════════════════════════════════════════════════
// ISLAND — Goals + Practice. Both use violet when active.
// ClipRRect + BorderRadius.only per side = identical shape each side
// ══════════════════════════════════════════════════════════════════
class _Island extends StatelessWidget {
  final String labelLeft, labelRight;
  final int idxLeft, idxRight, cur;
  final bool isDark;
  final VoidCallback onLeft, onRight;

  const _Island({
    required this.labelLeft,
    required this.labelRight,
    required this.idxLeft,
    required this.idxRight,
    required this.cur,
    required this.isDark,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final leftSel = cur == idxLeft;
    final rightSel = cur == idxRight;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.38);

    // Island outer radius — ClipRRect clips fills to this shape
    const double r = 20;

    return SizedBox(
      width: 130,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : const Color(0xFFF0F1F3),
              // No border needed — ClipRRect handles shape
            ),
            child: Row(children: [
              // ── LEFT: Goals ──────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onLeft();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    // Fill left half — only left corners rounded
                    decoration: BoxDecoration(
                      color: leftSel ? AppColors.violet : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(r),
                        bottomLeft: Radius.circular(r),
                      ),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: leftSel ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: Icon(Icons.flag_rounded,
                                size: 20,
                                color: leftSel ? Colors.white : inactive),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  leftSel ? FontWeight.w800 : FontWeight.w500,
                              color: leftSel ? Colors.white : inactive,
                            ),
                            child: Text(labelLeft),
                          ),
                        ]),
                  ),
                ),
              ),

              // ── Divider (only when neither active) ───────────
              if (!leftSel && !rightSel)
                Container(
                  width: 0.8,
                  height: 26,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.10),
                ),

              // ── RIGHT: Practice ──────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onRight();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    // Fill right half — only right corners rounded
                    decoration: BoxDecoration(
                      color: rightSel ? AppColors.violet : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(r),
                        bottomRight: Radius.circular(r),
                      ),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: rightSel ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: Icon(Icons.psychology_rounded,
                                size: 20,
                                color: rightSel ? Colors.white : inactive),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  rightSel ? FontWeight.w800 : FontWeight.w500,
                              color: rightSel ? Colors.white : inactive,
                            ),
                            child: Text(labelRight),
                          ),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// REGULAR TAB — violet when active (consistent with design system)
// ══════════════════════════════════════════════════════════════════
class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final bool isDark;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.idx,
    required this.cur,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = idx == cur;
    // ALL outer tabs use violet when active — consistent, not per-tab color
    final color = isSelected
        ? AppColors.violet
        : (isDark
            ? Colors.white.withValues(alpha: 0.38)
            : Colors.black.withValues(alpha: 0.38));

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(
            scale: isSelected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
        ]),
      ),
    );
  }
}
