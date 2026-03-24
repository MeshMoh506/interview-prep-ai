// lib/features/home/screens/home_screen.dart
import 'dart:ui';
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/transitions.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/dashboard/models/dashboard_model.dart';
import '../../../features/goals/providers/goal_provider.dart';
import '../../../features/goals/models/goal_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final userName = authState.user?.fullName.split(' ').first ?? 'User';

    // Load goals silently on home open
    ref.watch(goalProvider);

    return Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        bottomNavigationBar: const AppBottomNav(currentIndex: 0),
        body: Stack(children: [
          const BackgroundPainter(),
          dashState.isLoading && dashState.data == null
              ? _LoadingSkeleton(isDark: isDark, userName: userName)
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                  color: AppColors.violet,
                  displacement: 100,
                  child: dashState.data != null
                      ? _DashboardBody(
                          data: dashState.data!,
                          userName: userName,
                          isDark: isDark)
                      : _ErrorBody(
                          error: dashState.error,
                          onRetry: () =>
                              ref.read(dashboardProvider.notifier).refresh())),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SKELETON
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  final bool isDark;
  final String userName;
  const _LoadingSkeleton({required this.isDark, required this.userName});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
              userName: userName, isDark: isDark, onProfile: () {})),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _SkeletonBlock(height: 160, radius: 30, isDark: isDark),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Expanded(
                child: _SkeletonBlock(height: 70, radius: 18, isDark: isDark)),
            const SizedBox(width: 10),
            Expanded(
                child: _SkeletonBlock(height: 70, radius: 18, isDark: isDark)),
            const SizedBox(width: 10),
            Expanded(
                child: _SkeletonBlock(height: 70, radius: 18, isDark: isDark)),
          ]),
        ),
      ),
      // Active goal skeleton
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _SkeletonBlock(height: 80, radius: 20, isDark: isDark),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
          child:
              _SkeletonBlock(height: 12, width: 100, radius: 4, isDark: isDark),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4),
          delegate: SliverChildBuilderDelegate(
            (_, __) => _SkeletonBlock(height: 100, radius: 24, isDark: isDark),
            childCount: 4,
          ),
        ),
      ),
    ]);
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  final bool isDark;
  const _SkeletonBlock(
      {required this.height,
      this.width,
      required this.radius,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD BODY  — now ConsumerWidget to read goalProvider
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardBody extends ConsumerWidget {
  final DashboardData data;
  final String userName;
  final bool isDark;
  const _DashboardBody(
      {required this.data, required this.userName, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final goalState = ref.watch(goalProvider);
    final activeGoal = goalState.goals.where((g) => g.isActive).firstOrNull;

    return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── HEADER ─────────────────────────────────────────────
          SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                  userName: userName,
                  isDark: isDark,
                  onProfile: () => context.go('/profile'))),

          // ── HERO SCORE CARD ────────────────────────────────────
          SliverToBoxAdapter(
              child: _StaggerItem(
                  index: 0,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _HeroCard(data: data, isDark: isDark)))),

          // ── PROGRESS STRIP ─────────────────────────────────────
          SliverToBoxAdapter(
              child: _StaggerItem(
                  index: 1,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _ProgressStrip(data: data, isDark: isDark)))),

          // ── ACTIVE GOAL CARD (NEW) ─────────────────────────────
          if (activeGoal != null)
            SliverToBoxAdapter(
                child: _StaggerItem(
                    index: 2,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _ActiveGoalCard(
                            goal: activeGoal, isDark: isDark)))),

          // ── QUICK START BANNER ─────────────────────────────────
          SliverToBoxAdapter(
              child: _StaggerItem(
                  index: activeGoal != null ? 3 : 2,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _QuickStartBanner(data: data, isDark: isDark)))),

          // ── SPARKLINE ──────────────────────────────────────────
          if (data.scoreTrend.length >= 2)
            SliverToBoxAdapter(
                child: _StaggerItem(
                    index: activeGoal != null ? 4 : 3,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _SparklineCard(
                            trend: data.scoreTrend, isDark: isDark)))),

          // ── QUICK ACTIONS GRID ─────────────────────────────────
          SliverToBoxAdapter(
              child: _SectionHeader(s.homeQuickActions, isDark: isDark)),
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    _StaggerItem(
                        index: 5,
                        child: TapScale(
                            onTap: () => context.go('/interview'),
                            child: _ActionCard(
                                title: s.navInterview,
                                sub: s.homeAiMock,
                                icon: Icons.mic_rounded,
                                gradient: const [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF6D28D9)
                                ],
                                badge: data.interviewCount > 0
                                    ? '${data.interviewCount} ${s.homeDone}'
                                    : null,
                                onTap: () => context.go('/interview'),
                                isDark: isDark))),
                    _StaggerItem(
                        index: 6,
                        child: TapScale(
                            onTap: () => context.go('/resume'),
                            child: _ActionCard(
                                title: s.navResume,
                                sub:
                                    '${data.resumeCount} ${s.resumeUpload.toLowerCase()}',
                                icon: Icons.description_rounded,
                                gradient: const [
                                  Color(0xFF06B6D4),
                                  Color(0xFF0891B2)
                                ],
                                badge: data.resumeAnalyzed > 0
                                    ? '${data.resumeAnalyzed} ${s.homeAnalyzed}'
                                    : null,
                                onTap: () => context.go('/resume'),
                                isDark: isDark))),
                    _StaggerItem(
                        index: 7,
                        child: TapScale(
                            onTap: () => context.go('/goals'),
                            child: _ActionCard(
                                title: s.navGoals,
                                sub: activeGoal != null
                                    ? activeGoal.targetRole
                                    : s.goalMotivationalTitle,
                                icon: Icons.flag_rounded,
                                gradient: const [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF7C3AED)
                                ],
                                badge: activeGoal != null
                                    ? (Directionality.of(context) ==
                                            TextDirection.rtl
                                        ? 'نشط'
                                        : 'Active')
                                    : null,
                                onTap: () => context.go('/goals'),
                                isDark: isDark))),
                    _StaggerItem(
                        index: 8,
                        child: TapScale(
                            onTap: () => context.go('/profile'),
                            child: _ActionCard(
                                title: s.navProfile,
                                sub: s.homeSettingsStats,
                                icon: Icons.person_rounded,
                                gradient: const [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706)
                                ],
                                onTap: () => context.go('/profile'),
                                isDark: isDark))),
                  ]),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4))),

          // ── ACTIVE ROADMAP ─────────────────────────────────────
          if (data.activeRoadmap != null) ...[
            SliverToBoxAdapter(
                child: _SectionHeader(s.homeActiveRoadmap, isDark: isDark)),
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StaggerItem(
                        index: 9,
                        child: TapScale(
                            onTap: () => context
                                .go('/roadmap/${data.activeRoadmap!.id}'),
                            child: _RoadmapCard(
                                roadmap: data.activeRoadmap!,
                                isDark: isDark,
                                onTap: () => context.go(
                                    '/roadmap/${data.activeRoadmap!.id}')))))),
          ],

          // ── RECENT ACTIVITY ────────────────────────────────────
          SliverToBoxAdapter(
              child: _SectionHeader(s.homeRecentActivity, isDark: isDark)),
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (_, i) => _StaggerItem(
                          index: 10 + i,
                          child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TapScale(
                                  onTap: () {},
                                  child: _ActivityTile(
                                      item: data.activityFeed[i],
                                      isDark: isDark,
                                      onTap: () {})))),
                      childCount: data.activityFeed.take(4).length))),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ★ ACTIVE GOAL CARD  — shown on home when user has an active goal
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveGoalCard extends StatelessWidget {
  final GoalModel goal;
  final bool isDark;
  const _ActiveGoalCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final progress = goal.progress;
    final weekDone = progress?.thisWeekDone ?? goal.currentWeekCount;
    final weekTarget = progress?.thisWeekTarget ?? goal.weeklyInterviewTarget;
    final pct = weekTarget > 0 ? (weekDone / weekTarget).clamp(0.0, 1.0) : 0.0;
    final onTrack = weekDone >= weekTarget;
    final trackColor = onTrack ? AppColors.emerald : AppColors.violet;

    return TapScale(
      onTap: () => context.push('/goals/${goal.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.violet.withValues(alpha: isDark ? 0.18 : 0.09),
              AppColors.cyan.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.violet, size: 22),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                (isAr ? 'هدفك النشط' : 'ACTIVE GOAL').toUpperCase(),
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0),
              ),
              const SizedBox(height: 3),
              Text(
                goal.targetRole,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: AppColors.violet.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(trackColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: trackColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$weekDone/$weekTarget ${isAr ? 'أسبوعياً' : 'this wk'}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: trackColor),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          // Arrow
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAr
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: AppColors.violet,
              size: 13,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String userName;
  final bool isDark;
  final VoidCallback onProfile;
  _HeaderDelegate(
      {required this.userName, required this.isDark, required this.onProfile});

  @override
  double get minExtent => 100;
  @override
  double get maxExtent => 100;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final top = MediaQuery.of(context).padding.top;

    return ClipRRect(
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
                decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.9),
                    border: Border(
                        bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05)))),
                padding: EdgeInsets.fromLTRB(20, top + 12, 20, 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                          onTap: onProfile,
                          child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7C5CFC),
                                        Color(0xFF00D4FF)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF7C5CFC)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ]),
                              child: Center(
                                  child: Text(userName[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          height: 1))))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: isAr
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(s.timeGreeting,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                      letterSpacing: 0.2)),
                              const SizedBox(width: 6),
                              const _TimeOfDayDot(),
                            ]),
                            const SizedBox(height: 1),
                            Text('$userName 👋',
                                style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                    height: 1.1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ])),
                      const SizedBox(width: 10),
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
                                      : Colors.black.withValues(alpha: 0.06))),
                          child: const ThemeToggleButton()),
                    ]))));
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => true;
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────
class _TimeOfDayDot extends StatefulWidget {
  const _TimeOfDayDot();
  @override
  State<_TimeOfDayDot> createState() => _TimeOfDayDotState();
}

class _TimeOfDayDotState extends State<_TimeOfDayDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _anim = Tween(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _dotColor {
    final h = DateTime.now().hour;
    if (h < 6) return const Color(0xFF6366F1);
    if (h < 12) return const Color(0xFFF59E0B);
    if (h < 17) return const Color(0xFF10B981);
    if (h < 20) return const Color(0xFFEF4444);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              color: _dotColor.withValues(alpha: _anim.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _dotColor.withValues(alpha: 0.5 * _anim.value),
                    blurRadius: 6)
              ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final DashboardData data;
  final bool isDark;
  const _HeroCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final score = data.avgScore ?? 0;
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ]),
        child: Column(children: [
          Row(children: [
            _CircularScore(score: score),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.homeAvgScore,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text('${data.interviewsCompleted} ${s.homeSessionsDone}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _HeroStat(val: '${data.interviewCount}', label: s.homeInterviews),
            _HeroStat(val: '${data.resumeCount}', label: s.homeResumes),
            _HeroStat(val: '${data.roadmapCount}', label: s.homeRoadmaps),
          ]),
        ]));
  }
}

class _CircularScore extends StatelessWidget {
  final double score;
  const _CircularScore({required this.score});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 60,
      height: 60,
      child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            strokeCap: StrokeCap.round),
        Center(
            child: Text('${score.toInt()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16))),
      ]));
}

class _HeroStat extends StatelessWidget {
  final String val, label;
  const _HeroStat({required this.val, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        Text(label,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressStrip extends StatelessWidget {
  final DashboardData data;
  final bool isDark;
  const _ProgressStrip({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const weeklyGoal = 5;
    final weeklySessions = data.interviewCount.clamp(0, weeklyGoal * 2);
    final weeklyPct = (weeklySessions / weeklyGoal).clamp(0.0, 1.0);
    final streak = data.activeRoadmap?.streakDays ?? 0;
    final avgAts = data.resumeCount > 0 ? (data.avgScore ?? 0).toInt() : 0;

    return Row(children: [
      Expanded(
          child: _StripTile(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF6B35),
              value: '$streak',
              label: s.homeStreakDays,
              isDark: isDark)),
      const SizedBox(width: 10),
      Expanded(
          child: _StripTile(
              icon: Icons.calendar_today_rounded,
              iconColor: AppColors.violet,
              value: '$weeklySessions/$weeklyGoal',
              label: s.homeThisWeek,
              isDark: isDark,
              progress: weeklyPct,
              progressColor: AppColors.violet)),
      const SizedBox(width: 10),
      Expanded(
          child: _StripTile(
              icon: Icons.star_rounded,
              iconColor: AppColors.amber,
              value: avgAts > 0 ? '$avgAts%' : '--',
              label: s.homeAvgScore,
              isDark: isDark)),
    ]);
  }
}

class _StripTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value, label;
  final bool isDark;
  final double? progress;
  final Color? progressColor;
  const _StripTile(
      {required this.icon,
      required this.iconColor,
      required this.value,
      required this.label,
      required this.isDark,
      this.progress,
      this.progressColor});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87)),
        if (progress != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(progressColor!))),
        ],
      ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK START BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _QuickStartBanner extends StatelessWidget {
  final DashboardData data;
  final bool isDark;
  const _QuickStartBanner({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final lastRole = data.activityFeed.isNotEmpty
        ? data.activityFeed.first.title
        : 'Software Engineer';

    return TapScale(
        onTap: () => context.go('/interview/setup'),
        child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFC), Color(0xFF00D4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ]),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.homeQuickStart,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    const SizedBox(height: 3),
                    Text('${s.homeContinueAs} $lastRole',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
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
                      size: 14)),
            ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isDark;
  final String? badge;
  const _ActionCard(
      {required this.title,
      required this.sub,
      required this.icon,
      required this.gradient,
      required this.onTap,
      required this.isDark,
      this.badge});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.05))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 20)),
              if (badge != null) ...[
                const Spacer(),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: gradient[0].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(badge!,
                        style: TextStyle(
                            color: gradient[0],
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
              ],
            ]),
            const Spacer(),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            Text(sub,
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// ROADMAP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final ActiveRoadmapSummary roadmap;
  final bool isDark;
  final VoidCallback onTap;
  const _RoadmapCard(
      {required this.roadmap, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.05))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                    child: Text(roadmap.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis)),
                Text('${roadmap.overallProgress.toInt()}%',
                    style: const TextStyle(
                        color: AppColors.violet, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Text(
                  '${roadmap.milestonesDone}/${roadmap.milestonesTotal} ${s.roadmapMilestones} · '
                  '${roadmap.streakDays} ${s.roadmapStreak}',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 12),
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: roadmap.overallProgress / 100,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? Colors.white10 : Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.violet))),
            ])));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool isDark;
  final VoidCallback onTap;
  const _ActivityTile(
      {required this.item, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bolt_rounded,
                    color: AppColors.violet, size: 20)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(item.subtitle,
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLINE
// ─────────────────────────────────────────────────────────────────────────────
class _SparklineCard extends StatelessWidget {
  final List<ScoreTrend> trend;
  final bool isDark;
  const _SparklineCard({required this.trend, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final latest = trend.isNotEmpty ? trend.last.score : 0.0;
    final first = trend.isNotEmpty ? trend.first.score : 0.0;
    final delta = latest - first;
    final isUp = delta >= 0;

    return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.05))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(s.homePerfTrend,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54)),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: (isUp ? Colors.green : Colors.redAccent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: isUp ? Colors.green : Colors.redAccent),
                  const SizedBox(width: 4),
                  Text('${isUp ? '+' : ''}${delta.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isUp ? Colors.green : Colors.redAccent)),
                ])),
          ]),
          const SizedBox(height: 12),
          SizedBox(
              height: 60,
              child: CustomPaint(
                  painter: _SparklinePainter(trend: trend, isDark: isDark),
                  size: Size.infinite)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(trend.isNotEmpty ? trend.first.date : '',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38)),
            Text(trend.isNotEmpty ? trend.last.date : '',
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ]));
  }
}

class _SparklinePainter extends CustomPainter {
  final List<ScoreTrend> trend;
  final bool isDark;
  _SparklinePainter({required this.trend, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;
    final scores = trend.map((e) => e.score).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = (maxScore - minScore).clamp(1.0, double.infinity);
    final points = List.generate(
        trend.length,
        (i) => Offset(
            i / (trend.length - 1) * size.width,
            size.height -
                ((scores[i] - minScore) / range) * size.height * 0.85 -
                size.height * 0.075));

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.violet.withValues(alpha: isDark ? 0.25 : 0.15),
                AppColors.violet.withValues(alpha: 0.0),
              ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 =
          Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = AppColors.violet
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(points.last, 4, Paint()..color = AppColors.violet);
    canvas.drawCircle(points.last, 2,
        Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.trend != trend;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader(this.title, {required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      child: Text(title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.2)));
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BODY
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _ErrorBody({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded,
          color: Colors.redAccent, size: 48),
      const SizedBox(height: 16),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error ?? s.errUnexpected,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      TextButton(
          onPressed: onRetry,
          child: Text(s.tryAgain,
              style: const TextStyle(
                  color: AppColors.violet, fontWeight: FontWeight.bold))),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGER ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + (index * 100)),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        ),
        child: child,
      );
}
