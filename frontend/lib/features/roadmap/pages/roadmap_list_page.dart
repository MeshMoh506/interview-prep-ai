// lib/features/roadmap/pages/roadmap_list_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/transitions.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';
import '../../auth/screens/login_screen.dart';

class RoadmapListPage extends ConsumerWidget {
  const RoadmapListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roadmapListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: Stack(
        children: [
          const BackgroundPainter(),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Premium App Bar with Refresh Icon ──────────────────────────
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 120,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: FlexibleSpaceBar(
                      centerTitle: false,
                      titlePadding: const EdgeInsetsDirectional.only(
                          start: 20, bottom: 16),
                      title: Text(s.roadmapTitle,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5)),
                      background: Container(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Boxed Reload Icon (Replacing Theme Toggle)
                  GestureDetector(
                    onTap: () => ref.invalidate(roadmapListProvider),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),

              // ── Loading State ──────────────────────────────────────────────
              if (state.isLoading) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _SkeletonBlock(height: 100, radius: 28),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _SkeletonBlock(height: 80, radius: 24),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(top: 32),
                  sliver: SliverToBoxAdapter(child: ResumeListSkeleton()),
                ),
              ]

              // ── Error State ────────────────────────────────────────────────
              else if (state.error != null)
                SliverFillRemaining(
                    child: _ErrorState(
                        error: state.error!,
                        s: s,
                        onRetry: () => ref.invalidate(roadmapListProvider)))

              // ── Empty State ────────────────────────────────────────────────
              else if (state.roadmaps.isEmpty)
                SliverFillRemaining(child: _EmptyState(isDark: isDark, s: s))

              // ── Success State ──────────────────────────────────────────────
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _PremiumStatsBar(
                        roadmaps: state.roadmaps, isDark: isDark, s: s),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: TapScale(
                      onTap: () => context.push('/roadmap/create'),
                      child: _ModernCreateCard(isDark: isDark, s: s),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Text(isAr ? 'مساراتي' : 'MY PATHS',
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
                          s: s,
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
// SKELETON & COMPONENTS (Logic Kept Same)
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;
  const _SkeletonBlock({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PremiumStatsBar extends StatelessWidget {
  final List<Roadmap> roadmaps;
  final bool isDark;
  final AppStrings s;
  const _PremiumStatsBar(
      {required this.roadmaps, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final active = roadmaps.where((r) => r.overallProgress < 100).length;
    final avgPct = roadmaps.isEmpty
        ? 0.0
        : roadmaps.map((r) => r.overallProgress).reduce((a, b) => a + b) /
            roadmaps.length;
    final isAr = Directionality.of(context) == TextDirection.rtl;

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
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        _statItem('${roadmaps.length}', isAr ? 'الإجمالي' : 'Total',
            AppColors.violetLt),
        _divider(),
        _statItem('$active', isAr ? 'نشطة' : 'Active', AppColors.amber),
        _divider(),
        _statItem(
            '${avgPct.toInt()}%', isAr ? 'المتوسط' : 'Avg.', AppColors.cyan),
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

class _ModernCreateCard extends StatelessWidget {
  final bool isDark;
  final AppStrings s;
  const _ModernCreateCard({required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return GlassCard(
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
                  color: AppColors.emerald.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              const Icon(Icons.add_road_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isAr ? 'إنشاء خارطة جديدة' : 'Create New Roadmap',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(
                isAr
                    ? 'تحليل مسار التعلم بالذكاء الاصطناعي'
                    : 'AI-powered skill path analysis',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ),
        Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: AppColors.emerald),
      ]),
    );
  }
}

class _PremiumRoadmapCard extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark;
  final AppStrings s;
  final VoidCallback onTap;
  const _PremiumRoadmapCard(
      {required this.roadmap,
      required this.isDark,
      required this.s,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (roadmap.overallProgress / 100).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();
    final color = pct >= 80
        ? AppColors.emerald
        : pct >= 40
            ? AppColors.violet
            : AppColors.amber;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TapScale(
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
                      Text(
                          roadmap.targetRole ??
                              (isAr ? 'مسار مهاري' : 'Skill Path'),
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
              Text('$pct% ${isAr ? 'مكتمل' : 'Completed'}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: color)),
              Text('${roadmap.stages.length} ${isAr ? 'مراحل' : 'Stages'}',
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

class _ErrorState extends StatelessWidget {
  final String error;
  final AppStrings s;
  final VoidCallback onRetry;
  const _ErrorState(
      {required this.error, required this.s, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          TextButton(
              onPressed: onRetry,
              child: Text(s.tryAgain,
                  style: const TextStyle(color: AppColors.violet))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final AppStrings s;
  const _EmptyState({required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.map_outlined,
            size: 64, color: isDark ? Colors.white12 : Colors.black12),
        const SizedBox(height: 16),
        Text(s.roadmapNoRoadmaps,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        Text(
            isAr
                ? 'أنشئ أول مسار تعلم بالذكاء الاصطناعي'
                : 'Create your first AI-guided learning path',
            style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }
}
