// lib/features/roadmap/pages/roadmap_list_page.dart
// ignore_for_file: prefer_const_constructors
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard

class RoadmapListPage extends ConsumerWidget {
  const RoadmapListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roadmapListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: Stack(
        children: [
          // FIX 1: const + relative import (removed package:frontend/...)
          const BackgroundPainter(),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      // FIX 2: withOpacity → withValues (×2)
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                elevation: 0,
                title: Text('Roadmaps',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5)),
                actions: const [ThemeToggleButton(), SizedBox(width: 8)],
              ),
              if (!state.isLoading && state.roadmaps.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _PremiumStatsBar(
                        roadmaps: state.roadmaps, isDark: isDark),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _ModernCreateCard(isDark: isDark),
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.violet)),
                )
              else if (state.error != null)
                SliverFillRemaining(
                    child: _ErrorState(
                        error: state.error!,
                        onRetry: () => ref.invalidate(roadmapListProvider)))
              else if (state.roadmaps.isEmpty)
                SliverFillRemaining(child: _EmptyState(isDark: isDark))
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Text('MY PATHS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                            letterSpacing: 1.5)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _PremiumRoadmapCard(
                          roadmap: state.roadmaps[i],
                          isDark: isDark,
                          onTap: () =>
                              context.push('/roadmap/${state.roadmaps[i].id}')),
                      childCount: state.roadmaps.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumStatsBar extends StatelessWidget {
  final List<Roadmap> roadmaps;
  final bool isDark;
  const _PremiumStatsBar({required this.roadmaps, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final active = roadmaps.where((r) => r.overallProgress < 100).length;
    final avgPct = roadmaps.isEmpty
        ? 0.0
        : roadmaps.map((r) => r.overallProgress).reduce((a, b) => a + b) /
            roadmaps.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF4C1D95), const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              // FIX 3: withOpacity → withValues
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        _statItem('${roadmaps.length}', 'Total', AppColors.violetLt),
        _divider(),
        _statItem('$active', 'Active', AppColors.amber),
        _divider(),
        _statItem('${avgPct.toInt()}%', 'Avg.', AppColors.cyan),
      ]),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
        child: Column(children: [
          Text(v,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Text(l.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white10);
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ModernCreateCard extends StatelessWidget {
  final bool isDark;
  const _ModernCreateCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/roadmap/create'),
      child: GlassCard(
        isDark: isDark,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.emerald, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    // FIX 4: withOpacity → withValues
                    color: AppColors.emerald.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.add_road_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Create New Roadmap',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 2),
              Text('AI-powered skill path analysis',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.emerald),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROADMAP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumRoadmapCard extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark;
  final VoidCallback onTap;
  const _PremiumRoadmapCard(
      {required this.roadmap, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (roadmap.overallProgress / 100).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();
    final color = pct >= 80
        ? AppColors.emerald
        : pct >= 40
            ? AppColors.violet
            : AppColors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    // FIX 5: withOpacity → withValues
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.route_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roadmap.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87)),
                      Text(roadmap.targetRole ?? 'Skill Path',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38)),
                    ]),
              ),
              if (roadmap.isAiGenerated)
                const Icon(Icons.auto_awesome,
                    color: AppColors.violet, size: 16),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$pct% Completed',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: color)),
              Text('${roadmap.stages.length} Stages',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR / EMPTY STATES
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          TextButton(
              onPressed: onRetry,
              child: const Text('Try Again',
                  style: TextStyle(color: AppColors.violet))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.map_outlined,
              size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 16),
          const Text('No Roadmaps Found',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Create your first AI-guided learning path',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}
