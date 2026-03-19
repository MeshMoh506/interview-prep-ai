// lib/features/home/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/lang_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/transitions.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/dashboard/models/dashboard_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final userName = authState.user?.fullName.split(' ').first ?? 'User';

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: Stack(
        children: [
          const BackgroundPainter(),
          dashState.isLoading && dashState.data == null
              ? _LoadingSkeleton(isDark: isDark)
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(dashboardProvider.notifier).refresh(),
                  color: AppColors.violet,
                  displacement: 100,
                  child: dashState.data != null
                      ? _DashboardBody(
                          data: dashState.data!,
                          userName: userName,
                          isDark: isDark,
                        )
                      : _ErrorBody(
                          error: dashState.error,
                          onRetry: () =>
                              ref.read(dashboardProvider.notifier).refresh(),
                        ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final DashboardData data;
  final String userName;
  final bool isDark;

  const _DashboardBody({
    required this.data,
    required this.userName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            userName: userName,
            isDark: isDark,
            onProfile: () => context.go('/profile'),
          ),
        ),
        SliverToBoxAdapter(
          child: _StaggerItem(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _HeroCard(data: data, isDark: isDark),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _StaggerItem(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _ProgressStrip(data: data, isDark: isDark),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _StaggerItem(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _QuickStartBanner(data: data, isDark: isDark),
            ),
          ),
        ),
        if (data.scoreTrend.length >= 2)
          SliverToBoxAdapter(
            child: _StaggerItem(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _SparklineCard(trend: data.scoreTrend, isDark: isDark),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _SectionHeader(s.homeQuickActions, isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              _StaggerItem(
                index: 4,
                child: TapScale(
                  onTap: () => context.go('/interview'),
                  child: _ActionCard(
                    title: s.navInterview,
                    sub: s.homeAiMock,
                    icon: Icons.mic_rounded,
                    gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    badge: data.interviewCount > 0
                        ? '${data.interviewCount} ${s.homeDone}'
                        : null,
                    onTap: () => context.go('/interview'),
                    isDark: isDark,
                  ),
                ),
              ),
              _StaggerItem(
                index: 5,
                child: TapScale(
                  onTap: () => context.go('/resume'),
                  child: _ActionCard(
                    title: s.navResume,
                    sub: '${data.resumeCount} ${s.resumeUpload.toLowerCase()}',
                    icon: Icons.description_rounded,
                    gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                    badge: data.resumeAnalyzed > 0
                        ? '${data.resumeAnalyzed} ${s.homeAnalyzed}'
                        : null,
                    onTap: () => context.go('/resume'),
                    isDark: isDark,
                  ),
                ),
              ),
              _StaggerItem(
                index: 6,
                child: TapScale(
                  onTap: () => context.go('/roadmap'),
                  child: _ActionCard(
                    title: s.navRoadmap,
                    sub: data.activeRoadmap != null
                        ? '${data.activeRoadmap!.overallProgress.toInt()}% ${s.homeDone}'
                        : s.homeStartLearning,
                    icon: Icons.route_rounded,
                    gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                    onTap: () => context.go('/roadmap'),
                    isDark: isDark,
                  ),
                ),
              ),
              _StaggerItem(
                index: 7,
                child: TapScale(
                  onTap: () => context.go('/profile'),
                  child: _ActionCard(
                    title: s.navProfile,
                    sub: s.homeSettingsStats,
                    icon: Icons.person_rounded,
                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                    onTap: () => context.go('/profile'),
                    isDark: isDark,
                  ),
                ),
              ),
            ]),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
            ),
          ),
        ),
        if (data.activeRoadmap != null) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(s.homeActiveRoadmap, isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StaggerItem(
                index: 8,
                child: TapScale(
                  onTap: () => context.go('/roadmap/${data.activeRoadmap!.id}'),
                  child: _RoadmapCard(
                    roadmap: data.activeRoadmap!,
                    isDark: isDark,
                    onTap: () =>
                        context.go('/roadmap/${data.activeRoadmap!.id}'),
                  ),
                ),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: _SectionHeader(s.homeRecentActivity, isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _StaggerItem(
                index: 9 + i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TapScale(
                    onTap: () {},
                    child: _ActivityTile(
                      item: data.activityFeed[i],
                      isDark: isDark,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
              childCount: data.activityFeed.take(4).length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — time-aware greeting, global language toggle
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String userName;
  final bool isDark;
  final VoidCallback onProfile;

  _HeaderDelegate({
    required this.userName,
    required this.isDark,
    required this.onProfile,
  });

  @override
  double get minExtent => 110;
  @override
  double get maxExtent => 110;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final s = AppStrings.of(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.8),
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 10,
            20,
            10,
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.timeGreeting,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  Text(
                    '$userName 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Global language toggle — updates entire app
              // const LangToggleButton(),
              const SizedBox(width: 8),
              const ThemeToggleButton(),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.violet, AppColors.cyan],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => true;
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
          isDark: isDark,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StripTile(
          icon: Icons.calendar_today_rounded,
          iconColor: AppColors.violet,
          value: '$weeklySessions/$weeklyGoal',
          label: s.homeThisWeek,
          isDark: isDark,
          progress: weeklyPct,
          progressColor: AppColors.violet,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StripTile(
          icon: Icons.star_rounded,
          iconColor: AppColors.amber,
          value: avgAts > 0 ? '$avgAts%' : '--',
          label: s.homeAvgScore,
          isDark: isDark,
        ),
      ),
    ]);
  }
}

class _StripTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;
  final double? progress;
  final Color? progressColor;

  const _StripTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
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
                valueColor: AlwaysStoppedAnimation(progressColor!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK-START BANNER
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
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAr
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGER
// ─────────────────────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 20), child: c),
      ),
      child: child,
    );
  }
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
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStat(val: '${data.interviewCount}', label: s.homeInterviews),
              _HeroStat(val: '${data.resumeCount}', label: s.homeResumes),
              _HeroStat(val: '${data.roadmapCount}', label: s.homeRoadmaps),
            ],
          ),
        ],
      ),
    );
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
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text('${score.toInt()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
        ]),
      );
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
// ACTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isDark;
  final String? badge;

  const _ActionCard({
    required this.title,
    required this.sub,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gradient[0].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            color: gradient[0],
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14)),
              Text(sub,
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 10)),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ROADMAP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final ActiveRoadmapSummary roadmap;
  final bool isDark;
  final VoidCallback onTap;

  const _RoadmapCard({
    required this.roadmap,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(roadmap.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${roadmap.overallProgress.toInt()}%',
                  style: const TextStyle(
                      color: AppColors.violet, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${roadmap.milestonesDone}/${roadmap.milestonesTotal} ${s.roadmapMilestones} · '
            '${roadmap.streakDays} ${s.roadmapStreak}',
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: roadmap.overallProgress / 100,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppColors.violet),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: AppColors.violet, size: 20),
            ),
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
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLINE CARD
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
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.homePerfTrend,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isUp ? Colors.green : Colors.redAccent)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
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
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: CustomPaint(
            painter: _SparklinePainter(trend: trend, isDark: isDark),
            size: Size.infinite,
          ),
        ),
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
      ]),
    );
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
    final points = List.generate(trend.length, (i) {
      final x = i / (trend.length - 1) * size.width;
      final y = size.height -
          ((scores[i] - minScore) / range) * size.height * 0.85 -
          size.height * 0.075;
      return Offset(x, y);
    });
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
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
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
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
              letterSpacing: 1.2,
            )),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
        child: CircularProgressIndicator(
            color: AppColors.violet.withValues(alpha: 0.5)),
      );
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
        const Icon(Icons.error_outline_rounded,
            color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error ?? s.errUnexpected,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: Text(s.tryAgain,
              style: const TextStyle(
                  color: AppColors.violet, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
