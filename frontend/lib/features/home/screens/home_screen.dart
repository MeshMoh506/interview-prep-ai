import 'dart:ui';
// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/achievements_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/models/dashboard_model.dart';
import '../../goals/providers/goal_provider.dart';
import '../../goals/models/goal_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final userName = authState.user?.fullName.split(' ').first ?? 'User';
    ref.watch(goalProvider);

    final bg = isDark ? const Color(0xFF0E1117) : const Color(0xFFF7F8FC);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: dashState.isLoading && dashState.data == null
          ? _HomeSkeleton(isDark: isDark, userName: userName)
          : dashState.data != null
              ? RefreshIndicator(
                  onRefresh: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                  color: AppColors.violet,
                  displacement: 80,
                  child: _HomeBody(
                      data: dashState.data!,
                      userName: userName,
                      isDark: isDark))
              : _ErrorBody(
                  error: dashState.error,
                  onRetry: () =>
                      ref.read(dashboardProvider.notifier).refresh()),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MAIN BODY
// ══════════════════════════════════════════════════════════════════
class _HomeBody extends ConsumerWidget {
  final DashboardData data;
  final String userName;
  final bool isDark;
  const _HomeBody(
      {required this.data, required this.userName, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final goalState = ref.watch(goalProvider);
    final activeGoal = goalState.goals.where((g) => g.isActive).firstOrNull;
    final streak = data.activeRoadmap?.streakDays ?? 0;
    final top = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── STICKY HEADER ─────────────────────────────────────
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: _HeaderBar(
              userName: userName,
              isDark: isDark,
              onProfile: () => context.go('/profile')),
        ),

        // ── GREETING + HERO SCORE ──────────────────────────────
        SliverToBoxAdapter(
            child: _FadeSlide(
          delay: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ScoreHeroCard(data: data, isDark: isDark, isAr: isAr, s: s),
          ),
        )),

        // ── STATS PILLS ROW ─────────────────────────────────────
        SliverToBoxAdapter(
            child: _FadeSlide(
          delay: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _StatsPillRow(
                data: data, isDark: isDark, isAr: isAr, streak: streak),
          ),
        )),

        // ── ACTIVE GOAL BANNER ──────────────────────────────────
        if (activeGoal != null)
          SliverToBoxAdapter(
              child: _FadeSlide(
            delay: 120,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _GoalBanner(goal: activeGoal, isDark: isDark, isAr: isAr),
            ),
          )),

        // ── QUICK START CTA ─────────────────────────────────────
        SliverToBoxAdapter(
            child: _FadeSlide(
          delay: 160,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _QuickStartCTA(data: data, isDark: isDark, isAr: isAr, s: s),
          ),
        )),

        // ── SECTION LABEL: Quick Actions ───────────────────────
        SliverToBoxAdapter(
            child: _SectionHeader(title: s.homeQuickActions, isDark: isDark)),

        // ── 2×2 ACTION GRID ─────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.30),
            delegate: SliverChildListDelegate([
              _FadeSlide(
                  delay: 200,
                  child: _ActionTile(
                      title: s.navInterview,
                      sub: s.homeAiMock,
                      icon: Icons.mic_rounded,
                      color: AppColors.violet,
                      badge: data.interviewCount > 0
                          ? '${data.interviewCount} ${s.homeDone}'
                          : null,
                      onTap: () => context.go('/interview'),
                      isDark: isDark)),
              _FadeSlide(
                  delay: 240,
                  child: _ActionTile(
                      title: s.navResume,
                      sub:
                          '${data.resumeCount} ${s.resumeUpload.toLowerCase()}',
                      icon: Icons.description_rounded,
                      color: AppColors.cyan,
                      badge: data.resumeAnalyzed > 0
                          ? '${data.resumeAnalyzed} ${s.homeAnalyzed}'
                          : null,
                      onTap: () => context.go('/resume'),
                      isDark: isDark)),
              _FadeSlide(
                  delay: 280,
                  child: _ActionTile(
                      title: s.navGoals,
                      sub: activeGoal?.targetRole ?? s.goalMotivationalTitle,
                      icon: Icons.flag_rounded,
                      color: AppColors.emerald,
                      badge:
                          activeGoal != null ? (isAr ? 'نشط' : 'Active') : null,
                      onTap: () => context.go('/goals'),
                      isDark: isDark)),
              _FadeSlide(
                  delay: 320,
                  child: _ActionTile(
                      title: s.navRoadmap ?? 'Roadmap',
                      sub: data.activeRoadmap != null
                          ? '${data.activeRoadmap!.overallProgress.toInt()}%'
                          : (isAr ? 'أنشئ مساراً' : 'Create path'),
                      icon: Icons.map_rounded,
                      color: AppColors.amber,
                      badge: null,
                      onTap: () => context.go('/roadmap'),
                      isDark: isDark)),
            ]),
          ),
        ),

        // ── ACHIEVEMENTS ────────────────────────────────────────
        SliverToBoxAdapter(
            child: _SectionHeader(
                title: isAr ? 'إنجازاتك' : 'YOUR ACHIEVEMENTS',
                isDark: isDark)),
        SliverToBoxAdapter(
            child: _FadeSlide(
          delay: 360,
          child: AchievementsWidget(
            interviewCount: data.interviewCount,
            avgScore: data.avgScore ?? 0,
            streak: streak,
            resumeCount: data.resumeCount,
            roadmapCount: data.roadmapCount,
            goalsAchieved: 0,
            isDark: isDark,
            isAr: isAr,
            compact: true,
          ),
        )),

        // ── SCORE TREND ──────────────────────────────────────────
        if (data.scoreTrend.length >= 2) ...[
          SliverToBoxAdapter(
              child: _SectionHeader(title: s.homePerfTrend, isDark: isDark)),
          SliverToBoxAdapter(
              child: _FadeSlide(
            delay: 400,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TrendCard(trend: data.scoreTrend, isDark: isDark),
            ),
          )),
        ],

        // ── ACTIVE ROADMAP ───────────────────────────────────────
        if (data.activeRoadmap != null) ...[
          SliverToBoxAdapter(
              child:
                  _SectionHeader(title: s.homeActiveRoadmap, isDark: isDark)),
          SliverToBoxAdapter(
              child: _FadeSlide(
            delay: 420,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _RoadmapCard(
                  roadmap: data.activeRoadmap!,
                  isDark: isDark,
                  isAr: isAr,
                  onTap: () =>
                      context.go('/roadmap/${data.activeRoadmap!.id}')),
            ),
          )),
        ],

        // ── RECENT ACTIVITY ──────────────────────────────────────
        if (data.activityFeed.isNotEmpty) ...[
          SliverToBoxAdapter(
              child:
                  _SectionHeader(title: s.homeRecentActivity, isDark: isDark)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (_, i) => _FadeSlide(
                  delay: 440 + i * 40,
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityTile(
                          item: data.activityFeed[i], isDark: isDark))),
              childCount: data.activityFeed.take(4).length,
            )),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HEADER — pinned, blurred
// ══════════════════════════════════════════════════════════════════
class _HeaderBar extends StatelessWidget {
  final String userName;
  final bool isDark;
  final VoidCallback onProfile;
  const _HeaderBar(
      {required this.userName, required this.isDark, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final top = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          color: isDark
              ? const Color(0xFF0E1117).withValues(alpha: 0.90)
              : const Color(0xFFF7F8FC).withValues(alpha: 0.92),
          padding: EdgeInsets.fromLTRB(20, top + 10, 20, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onProfile();
              },
              child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF8B5CF6).withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Center(
                      child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _PulsingDot(),
                  const SizedBox(width: 5),
                  Text(s.timeGreeting,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.black.withValues(alpha: 0.38))),
                ]),
                Text('$userName 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.2,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A2E))),
              ],
            )),
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                ),
                child: const ThemeToggleButton()),
          ]),
        ),
      ),
    );
  }
}

class _ScoreHeroCard extends StatelessWidget {
  final DashboardData data;
  final bool isDark, isAr;
  final AppStrings s;
  const _ScoreHeroCard(
      {required this.data,
      required this.isDark,
      required this.isAr,
      required this.s});

  @override
  Widget build(BuildContext context) {
    final score = data.avgScore ?? 0;
    final sc = score >= 70
        ? AppColors.emerald
        : score >= 40
            ? AppColors.amber
            : AppColors.rose;
    final grade = score >= 80
        ? '🏆 ${isAr ? "ممتاز" : "Excellent"}'
        : score >= 60
            ? '⭐ ${isAr ? "جيد" : "Good"}'
            : '📈 ${isAr ? "في تقدم" : "Improving"}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C25) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: [
        // Animated score ring
        _ScoreRing(score: score, color: sc),
        const SizedBox(width: 20),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.homeAvgScore,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.60)
                      : Colors.black.withValues(alpha: 0.45))),
          const SizedBox(height: 4),
          Text('${data.interviewsCompleted} ${s.homeSessionsDone}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withValues(alpha: 0.20)),
            ),
            child: Text(grade,
                style: TextStyle(
                    color: sc, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ])),
        // Vertical divider + right stats
        Container(
            width: 1,
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06)),
        Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MiniStat('${data.interviewCount}', s.homeInterviews,
                  isDark: isDark),
              const SizedBox(height: 12),
              _MiniStat('${data.resumeCount}', s.homeResumes, isDark: isDark),
              const SizedBox(height: 12),
              _MiniStat('${data.roadmapCount}', s.homeRoadmaps, isDark: isDark),
            ]),
      ]),
    );
  }
}

class _ScoreRing extends StatefulWidget {
  final double score;
  final Color color;
  const _ScoreRing({required this.score, required this.color});
  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  late final Animation<double> _a =
      Tween<double>(begin: 0, end: widget.score / 100)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) => SizedBox(
          width: 80,
          height: 80,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(
              value: _a.value.clamp(0.0, 1.0),
              strokeWidth: 7,
              backgroundColor: widget.color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(widget.color),
              strokeCap: StrokeCap.round,
            ),
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(_a.value * 100).toInt()}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: widget.color,
                      letterSpacing: -1)),
              Text('%',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: widget.color.withValues(alpha: 0.60))),
            ])),
          ]),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String val, label;
  final bool isDark;
  const _MiniStat(this.val, this.label, {required this.isDark});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.black38),
            textAlign: TextAlign.center),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// STATS PILLS ROW — 3 horizontal pills
// ══════════════════════════════════════════════════════════════════
class _StatsPillRow extends StatelessWidget {
  final DashboardData data;
  final bool isDark, isAr;
  final int streak;
  const _StatsPillRow(
      {required this.data,
      required this.isDark,
      required this.isAr,
      required this.streak});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final avg = data.avgScore ?? 0;
    final weekDone = data.interviewCount.clamp(0, 10);

    return Row(children: [
      _StatPill(
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF6B35),
        value: '$streak',
        label: s.homeStreakDays,
        isDark: isDark,
      ),
      const SizedBox(width: 10),
      _StatPill(
        icon: Icons.calendar_today_rounded,
        color: AppColors.violet,
        value: '$weekDone/5',
        label: s.homeThisWeek,
        isDark: isDark,
        progress: (weekDone / 5).clamp(0.0, 1.0),
      ),
      const SizedBox(width: 10),
      _StatPill(
        icon: Icons.star_rounded,
        color: AppColors.amber,
        value: avg > 0 ? '${avg.toInt()}%' : '--',
        label: s.homeAvgScore,
        isDark: isDark,
      ),
    ]);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  final bool isDark;
  final double? progress;
  const _StatPill(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label,
      required this.isDark,
      this.progress});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C25) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.30)
                              : Colors.black38),
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress!),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: color.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation(color)),
                  )),
            ],
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// GOAL BANNER — active goal strip
// ══════════════════════════════════════════════════════════════════
class _GoalBanner extends StatelessWidget {
  final GoalModel goal;
  final bool isDark, isAr;
  const _GoalBanner(
      {required this.goal, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final pct = goal.weeklyInterviewTarget > 0
        ? (goal.currentWeekCount / goal.weeklyInterviewTarget).clamp(0.0, 1.0)
        : 0.0;
    final onTrack = goal.currentWeekCount >= goal.weeklyInterviewTarget;
    final trackColor = onTrack ? AppColors.emerald : AppColors.violet;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/goals/${goal.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C25) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withValues(alpha: isDark ? 0.10 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.flag_rounded,
                  color: AppColors.violet, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text((isAr ? 'هدفك النشط' : 'ACTIVE GOAL').toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.violet,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(goal.targetRole,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor:
                              AppColors.violet.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(trackColor)),
                    )),
              ])),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: trackColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Text(
                '${goal.currentWeekCount}/${goal.weeklyInterviewTarget}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: trackColor)),
          ),
          const SizedBox(width: 6),
          Icon(
              isAr
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: AppColors.violet,
              size: 12),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// QUICK START CTA — full width button-card
// ══════════════════════════════════════════════════════════════════
class _QuickStartCTA extends StatelessWidget {
  final DashboardData data;
  final bool isDark, isAr;
  final AppStrings s;
  const _QuickStartCTA(
      {required this.data,
      required this.isDark,
      required this.isAr,
      required this.s});

  @override
  Widget build(BuildContext context) {
    final lastRole = data.activityFeed.isNotEmpty
        ? data.activityFeed.first.title
        : 'Software Engineer';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.go('/interview/setup');
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 32)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.homeQuickStart,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17)),
                const SizedBox(height: 3),
                Text('${s.homeContinueAs} $lastRole',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(
                  isAr
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 13)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ACTION TILE — 2×2 grid card (reference: Real Estate category cards)
// ══════════════════════════════════════════════════════════════════
class _ActionTile extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  final bool isDark;
  const _ActionTile(
      {required this.title,
      required this.sub,
      required this.icon,
      required this.color,
      this.badge,
      required this.onTap,
      required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C25) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 22)),
              if (badge != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(badge!,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
            const Spacer(),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.30)
                        : Colors.black38),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// TREND CARD — sparkline
// ══════════════════════════════════════════════════════════════════
class _TrendCard extends StatelessWidget {
  final List<ScoreTrend> trend;
  final bool isDark;
  const _TrendCard({required this.trend, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final latest = trend.isNotEmpty ? trend.last.score : 0.0;
    final first = trend.isNotEmpty ? trend.first.score : 0.0;
    final delta = latest - first;
    final isUp = delta >= 0;
    final dc = isUp ? AppColors.emerald : AppColors.rose;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C25) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Text('${latest.toInt()}%',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -1,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: dc.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: dc),
              const SizedBox(width: 3),
              Text('${isUp ? "+" : ""}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: dc)),
            ]),
          ),
          const Spacer(),
          Text('${trend.length} sessions',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black38)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
            height: 60,
            child: CustomPaint(
                painter: _SparkPainter(trend: trend, isDark: isDark),
                size: Size.infinite)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(trend.isNotEmpty ? trend.first.date : '',
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black38)),
          Text(trend.isNotEmpty ? trend.last.date : '',
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black38)),
        ]),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<ScoreTrend> trend;
  final bool isDark;
  _SparkPainter({required this.trend, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;
    final scores = trend.map((e) => e.score).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = (maxScore - minScore).clamp(1.0, double.infinity);
    final pts = List.generate(
        trend.length,
        (i) => Offset(
            i / (trend.length - 1) * size.width,
            size.height -
                ((scores[i] - minScore) / range) * size.height * 0.80 -
                size.height * 0.10));

    final fill = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(pts.last.dx, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.violet.withValues(alpha: isDark ? 0.25 : 0.12),
                AppColors.violet.withValues(alpha: 0)
              ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      line.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.violet
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(pts.last, 5, Paint()..color = AppColors.violet);
    canvas.drawCircle(pts.last, 2.5,
        Paint()..color = isDark ? const Color(0xFF181C25) : Colors.white);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.trend != trend;
}

// ══════════════════════════════════════════════════════════════════
// ROADMAP CARD
// ══════════════════════════════════════════════════════════════════
class _RoadmapCard extends StatelessWidget {
  final ActiveRoadmapSummary roadmap;
  final bool isDark, isAr;
  final VoidCallback onTap;
  const _RoadmapCard(
      {required this.roadmap,
      required this.isDark,
      required this.isAr,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C25) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map_rounded,
                    color: AppColors.emerald, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(roadmap.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            Text('${roadmap.overallProgress.toInt()}%',
                style: const TextStyle(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w900,
                    fontSize: 17)),
          ]),
          const SizedBox(height: 8),
          Text(
              '${roadmap.milestonesDone}/${roadmap.milestonesTotal} ${s.roadmapMilestones}',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: 0.38))),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: roadmap.overallProgress / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    backgroundColor: AppColors.emerald.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.emerald)),
              )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ACTIVITY TILE
// ══════════════════════════════════════════════════════════════════
class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool isDark;
  const _ActivityTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C25) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.bolt_rounded,
                  color: AppColors.violet, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.38)
                            : Colors.black.withValues(alpha: 0.38))),
              ])),
          Icon(Icons.chevron_right_rounded,
              size: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black26),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// SHIMMER SKELETON
// ══════════════════════════════════════════════════════════════════
class _HomeSkeleton extends StatefulWidget {
  final bool isDark;
  final String userName;
  const _HomeSkeleton({required this.isDark, required this.userName});
  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final v = 0.04 + 0.07 * _a.value;
          final card = widget.isDark ? const Color(0xFF181C25) : Colors.white;
          final hi = widget.isDark
              ? Colors.white.withValues(alpha: v)
              : Colors.black.withValues(alpha: v);
          final lo = widget.isDark
              ? Colors.white.withValues(alpha: v * 0.5)
              : Colors.black.withValues(alpha: v * 0.5);

          Widget bone(double w, double h, {double r = 10, Color? c}) =>
              Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                      color: c ?? lo, borderRadius: BorderRadius.circular(r)));

          Widget cardWrap({required Widget child, double p = 16}) => Container(
              padding: EdgeInsets.all(p),
              decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: widget.isDark ? 0.20 : 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ]),
              child: child);

          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Header ──────────────────────────────────────────
              Container(
                color: widget.isDark
                    ? const Color(0xFF0E1117)
                    : const Color(0xFFF7F8FC),
                padding: EdgeInsets.fromLTRB(20, top + 12, 20, 12),
                child: Row(children: [
                  bone(42, 42, r: 13, c: hi),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        bone(60, 9, r: 5),
                        const SizedBox(height: 6),
                        bone(130, 18, r: 7, c: hi),
                      ])),
                  bone(40, 40, r: 12),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                // ── Score hero card ───────────────────────────────
                child: cardWrap(
                    p: 24,
                    child: Row(children: [
                      bone(80, 80, r: 40, c: hi), // ring
                      const SizedBox(width: 20),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            bone(80, 12, r: 5),
                            const SizedBox(height: 8),
                            bone(120, 14, r: 5, c: hi),
                            const SizedBox(height: 12),
                            bone(90, 26, r: 14),
                          ])),
                      Container(
                          width: 1,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: lo),
                      Column(children: [
                        bone(28, 14, r: 5, c: hi),
                        const SizedBox(height: 4),
                        bone(40, 8, r: 4),
                        const SizedBox(height: 12),
                        bone(28, 14, r: 5, c: hi),
                        const SizedBox(height: 4),
                        bone(40, 8, r: 4),
                        const SizedBox(height: 12),
                        bone(28, 14, r: 5, c: hi),
                        const SizedBox(height: 4),
                        bone(40, 8, r: 4),
                      ]),
                    ])),
              ),

              const SizedBox(height: 14),

              // ── Stats pills ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                    children: List.generate(
                        3,
                        (i) => Expanded(
                              child: Container(
                                margin: EdgeInsets.only(left: i > 0 ? 10 : 0),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha:
                                                  widget.isDark ? 0.20 : 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3))
                                    ]),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      bone(50, 9, r: 4),
                                      const SizedBox(height: 8),
                                      bone(36, 20, r: 6, c: hi),
                                    ]),
                              ),
                            ))),
              ),

              const SizedBox(height: 14),

              // ── Quick start CTA ───────────────────────────────
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                      height: 76,
                      decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22)))),

              const SizedBox(height: 24),

              // ── Section label ─────────────────────────────────
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: bone(120, 11, r: 5)),

              // ── 2×2 grid ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.30,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(
                      4,
                      (_) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: widget.isDark ? 0.20 : 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4))
                              ]),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bone(44, 44, r: 14, c: hi),
                                const Spacer(),
                                bone(80, 13, r: 5, c: hi),
                                const SizedBox(height: 6),
                                bone(60, 9, r: 4),
                              ]))),
                ),
              ),
            ]),
          );
        });
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.black38)),
      );
}

class _FadeSlide extends StatelessWidget {
  final int delay;
  final Widget child;
  const _FadeSlide({required this.delay, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + delay),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 20 * (1 - v)), child: child)),
        child: child,
      );
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final Animation<double> _a = Tween(begin: 0.5, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color get _color {
    final h = DateTime.now().hour;
    if (h < 6) return const Color(0xFF6366F1);
    if (h < 12) return const Color(0xFFF59E0B);
    if (h < 17) return const Color(0xFF10B981);
    if (h < 20) return const Color(0xFFEF4444);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: _a.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _color.withValues(alpha: 0.4 * _a.value),
                    blurRadius: 5)
              ],
            ),
          ));
}

class _ErrorBody extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _ErrorBody({this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('😕', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      Text(error ?? s.errUnexpected,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Text(s.tryAgain)),
    ]));
  }
}
