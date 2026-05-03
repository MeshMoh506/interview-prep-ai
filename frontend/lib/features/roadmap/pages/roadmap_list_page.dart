// lib/features/roadmap/pages/roadmap_list_page.dart
//
// Redesigned to match design system:
//   • Same header layout (greeting + title + action buttons)
//   • Same gradient stats card (violet→cyan)
//   • Same card style with progress ring
//   • No BackgroundPainter / GlassCard old widgets
//   • Shimmer skeleton matching actual layout

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';

class RoadmapListPage extends ConsumerWidget {
  const RoadmapListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roadmapListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final authState = ref.watch(authProvider);
    final firstName = authState.user?.fullName.split(' ').first ?? '';
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: MediaQuery.of(context).padding.top),

        // ── Header ──────────────────────────────────────────
        _Header(
          isDark: isDark,
          isAr: isAr,
          firstName: firstName,
          onRefresh: () => ref.invalidate(roadmapListProvider),
          onAdd: () => context.push('/roadmap/create'),
        ),

        // ── Body ────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? _Shimmer(isDark: isDark)
              : state.error != null
                  ? _ErrView(
                      isDark: isDark,
                      isAr: isAr,
                      onRetry: () => ref.invalidate(roadmapListProvider))
                  : state.roadmaps.isEmpty
                      ? _EmptyView(
                          isDark: isDark,
                          isAr: isAr,
                          onAdd: () => context.push('/roadmap/create'))
                      : _RoadmapBody(
                          roadmaps: state.roadmaps,
                          isDark: isDark,
                          isAr: isAr,
                          onTap: (id) => context.push('/roadmap/$id'),
                          onAdd: () => context.push('/roadmap/create'),
                        ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isDark, isAr;
  final String firstName;
  final VoidCallback onRefresh, onAdd;
  const _Header({
    required this.isDark,
    required this.isAr,
    required this.firstName,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (firstName.isNotEmpty)
                Text(
                  isAr ? 'مرحباً، $firstName' : 'Hello, $firstName',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.40)),
                ),
              Text(
                isAr ? 'مساراتي' : 'My Roadmaps',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20)),
              ),
            ]),
            Row(children: [
              // Refresh
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onRefresh();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.refresh_rounded,
                      size: 20,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : Colors.black.withValues(alpha: 0.60)),
                ),
              ),
              const SizedBox(width: 10),
              // Add
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onAdd();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.violet,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.40),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ]),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// BODY WITH DATA
// ══════════════════════════════════════════════════════════════════
class _RoadmapBody extends StatelessWidget {
  final List<Roadmap> roadmaps;
  final bool isDark, isAr;
  final void Function(int) onTap;
  final VoidCallback onAdd;
  const _RoadmapBody({
    required this.roadmaps,
    required this.isDark,
    required this.isAr,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final active = roadmaps.where((r) => r.overallProgress < 100).length;
    final avg = roadmaps.isEmpty
        ? 0
        : (roadmaps.map((r) => r.overallProgress).reduce((a, b) => a + b) /
                roadmaps.length)
            .toInt();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Stats card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _StatsCard(
                total: roadmaps.length,
                active: active,
                avg: avg,
                isDark: isDark,
                isAr: isAr),
          ),
        ),

        // Create card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onAdd();
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222C) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.18 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.add_road_rounded,
                        color: AppColors.emerald, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isAr ? 'إنشاء خارطة جديدة' : 'Create New Roadmap',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1C20))),
                          const SizedBox(height: 3),
                          Text(
                              isAr
                                  ? 'مسار تعلم بالذكاء الاصطناعي'
                                  : 'AI-powered skill path',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.38)
                                      : Colors.black.withValues(alpha: 0.38))),
                        ]),
                  ),
                  Icon(
                      isAr
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.emerald),
                ]),
              ),
            ),
          ),
        ),

        // Section label
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            child: Text(
              (isAr ? 'مساراتي' : 'MY PATHS').toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),

        // Roadmap cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _RoadmapCard(
                roadmap: roadmaps[i],
                index: i,
                isDark: isDark,
                isAr: isAr,
                onTap: () => onTap(roadmaps[i].id),
              ),
              childCount: roadmaps.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STATS CARD — violet→cyan gradient, matches interview list
// ══════════════════════════════════════════════════════════════════
class _StatsCard extends StatelessWidget {
  final int total, active, avg;
  final bool isDark, isAr;
  const _StatsCard({
    required this.total,
    required this.active,
    required this.avg,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B2BE2), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7B3FE4).withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _S(isAr ? 'الإجمالي' : 'TOTAL', '$total'),
            Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.20)),
            _S(isAr ? 'نشطة' : 'ACTIVE', '$active'),
            Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.20)),
            _S(isAr ? 'المتوسط' : 'AVG', avg > 0 ? '$avg%' : '—'),
          ],
        ),
      );

  Widget _S(String l, String v) => Column(children: [
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        const SizedBox(height: 3),
        Text(l,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// ROADMAP CARD — matches interview card style with progress ring
// ══════════════════════════════════════════════════════════════════
class _RoadmapCard extends StatelessWidget {
  final Roadmap roadmap;
  final int index;
  final bool isDark, isAr;
  final VoidCallback onTap;
  const _RoadmapCard({
    required this.roadmap,
    required this.index,
    required this.isDark,
    required this.isAr,
    required this.onTap,
  });

  Color get _color {
    final p = roadmap.overallProgress;
    if (p >= 80) return AppColors.emerald;
    if (p >= 40) return AppColors.violet;
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 16 * (1 - v)), child: child)),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222C) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(children: [
              // Progress ring
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: (roadmap.overallProgress / 100).clamp(0.0, 1.0),
                    strokeWidth: 4,
                    color: _color,
                    backgroundColor: _color.withValues(alpha: 0.12),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      roadmap.overallProgress > 0
                          ? '${roadmap.overallProgress.toInt()}%'
                          : roadmap.stages.isNotEmpty
                              ? roadmap.stages.first.icon ?? '📚'
                              : '📚',
                      style: TextStyle(
                          color: roadmap.overallProgress > 0 ? _color : null,
                          fontSize: roadmap.overallProgress > 0 ? 11 : 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roadmap.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1C20)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        _Chip(
                            '${roadmap.completedTasks}/${roadmap.totalTasks} ${isAr ? "مهمة" : "tasks"}',
                            AppColors.violet),
                        const SizedBox(width: 6),
                        if (roadmap.difficulty != null)
                          _Chip(roadmap.difficulty!, AppColors.amber),
                        const Spacer(),
                        if (roadmap.isAiGenerated)
                          const Icon(Icons.auto_awesome_rounded,
                              size: 13, color: AppColors.violet),
                      ]),
                    ]),
              ),
              const SizedBox(width: 8),
              Icon(
                  isAr
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.black.withValues(alpha: 0.20)),
            ]),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

// ══════════════════════════════════════════════════════════════════
// EMPTY + ERROR
// ══════════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onAdd;
  const _EmptyView(
      {required this.isDark, required this.isAr, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.map_rounded,
                    color: AppColors.violet, size: 40)),
            const SizedBox(height: 18),
            Text(isAr ? 'لا توجد مسارات بعد' : 'No Roadmaps Yet',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20))),
            const SizedBox(height: 8),
            Text(
                isAr
                    ? 'أنشئ مسار تعلم بالذكاء الاصطناعي'
                    : 'Create your first AI-guided learning path',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.38)
                        : Colors.black.withValues(alpha: 0.38))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onAdd();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ]),
                child: Text(isAr ? 'إنشاء الآن' : 'Create Now',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      );
}

class _ErrView extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onRetry;
  const _ErrView(
      {required this.isDark, required this.isAr, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.rose),
          const SizedBox(height: 12),
          Text(isAr ? 'فشل التحميل' : 'Failed to load',
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// SHIMMER
// ══════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final bool isDark;
  const _Shimmer({required this.isDark});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final v = 0.04 + 0.07 * _a.value;
        final hi = widget.isDark
            ? Colors.white.withValues(alpha: v)
            : Colors.black.withValues(alpha: v);
        final lo = widget.isDark
            ? Colors.white.withValues(alpha: v * 0.45)
            : Colors.black.withValues(alpha: v * 0.45);
        final card = widget.isDark ? const Color(0xFF1E222C) : Colors.white;

        Widget b(double w, double h, {double r = 8, Color? c}) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                color: c ?? lo, borderRadius: BorderRadius.circular(r)));

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            // Stats card
            b(double.infinity, 88,
                r: 26, c: AppColors.violet.withValues(alpha: 0.14)),
            const SizedBox(height: 14),
            // Create card
            Container(
                height: 72,
                decoration: BoxDecoration(
                    color: card, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 24),
            // Cards
            ...List.generate(
                4,
                (i) => Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: card, borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        b(56, 56, r: 28, c: hi),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              b(i.isEven ? 130.0 : 110.0, 14, r: 6, c: hi),
                              const SizedBox(height: 8),
                              Row(children: [
                                b(70, 10, r: 5),
                                const SizedBox(width: 6),
                                b(50, 10, r: 5),
                              ]),
                            ])),
                        const SizedBox(width: 8),
                        b(14, 14, r: 7),
                      ]),
                    )),
          ]),
        );
      });
}
