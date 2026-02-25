// lib/features/home/screens/home_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
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
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F4FF),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: dashState.isLoading && dashState.data == null
          ? _LoadingSkeleton(isDark: isDark)
          : RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              color: AppColors.violet,
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Sticky header ──────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            userName: userName,
            isDark: isDark,
            onProfile: () => context.go('/profile'),
          ),
        ),

        // ── Hero performance card ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _HeroCard(data: data, isDark: isDark),
          ),
        ),

        // ── Score sparkline ────────────────────────────────────
        if (data.scoreTrend.length >= 2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SparklineCard(trend: data.scoreTrend, isDark: isDark),
            ),
          ),

        // ── Quick Actions ──────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader('Quick Actions', isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              _ActionCard(
                title: 'Interview',
                sub: 'AI mock session',
                icon: Icons.mic_rounded,
                gradient: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                badge: data.interviewCount > 0
                    ? '${data.interviewCount} done'
                    : null,
                onTap: () => context.go('/interview'),
                isDark: isDark,
              ),
              _ActionCard(
                title: 'Resumes',
                sub: '${data.resumeCount} uploaded',
                icon: Icons.description_rounded,
                gradient: const [Color(0xFF0891B2), Color(0xFF0E7490)],
                badge: data.resumeAnalyzed > 0
                    ? '${data.resumeAnalyzed} analyzed'
                    : null,
                onTap: () => context.go('/resume'),
                isDark: isDark,
              ),
              _ActionCard(
                title: 'Roadmap',
                sub: data.activeRoadmap != null
                    ? '${data.activeRoadmap!.overallProgress.toInt()}% done'
                    : 'Start learning',
                icon: Icons.route_rounded,
                gradient: const [Color(0xFF059669), Color(0xFF047857)],
                badge: data.activeRoadmap != null
                    ? '${data.activeRoadmap!.milestonesDone}/${data.activeRoadmap!.milestonesTotal}'
                    : null,
                onTap: () => context.go('/roadmap'),
                isDark: isDark,
              ),
              _ActionCard(
                title: 'Profile',
                sub: 'Settings & stats',
                icon: Icons.person_rounded,
                gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                onTap: () => context.go('/profile'),
                isDark: isDark,
              ),
            ]),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
          ),
        ),

        // ── Active roadmap ─────────────────────────────────────
        if (data.activeRoadmap != null) ...[
          SliverToBoxAdapter(
            child: _SectionHeader('Active Roadmap', isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RoadmapCard(
                roadmap: data.activeRoadmap!,
                isDark: isDark,
                onTap: () => context.go('/roadmap/${data.activeRoadmap!.id}'),
              ),
            ),
          ),
        ],

        // ── Recent interviews ──────────────────────────────────
        if (data.recentInterviews.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              'Recent Interviews',
              isDark: isDark,
              action: TextButton(
                onPressed: () => context.go('/interview'),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InterviewTile(
                    interview: data.recentInterviews[i],
                    isDark: isDark,
                    onTap: () => context.go('/interview'),
                  ),
                ),
                childCount: data.recentInterviews.take(3).length,
              ),
            ),
          ),
        ],

        // ── Motivational tip ───────────────────────────────────
        if (data.tip.title.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _TipCard(tip: data.tip, isDark: isDark),
            ),
          ),

        // ── Activity feed ──────────────────────────────────────
        if (data.activityFeed.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader('Recent Activity', isDark: isDark),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActivityTile(
                    item: data.activityFeed[i],
                    isDark: isDark,
                    onTap: () =>
                        _handleActivityTap(context, data.activityFeed[i].type),
                  ),
                ),
                childCount: data.activityFeed.take(4).length,
              ),
            ),
          ),
        ],

        // ── Skills to strengthen ───────────────────────────────
        if (data.skillGaps.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader('Skills to Strengthen', isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.skillGaps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _SkillChip(label: data.skillGaps[i]),
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  void _handleActivityTap(BuildContext context, String type) {
    switch (type) {
      case 'interview':
        context.go('/interview');
        break;
      case 'resume':
        context.go('/resume');
        break;
      case 'roadmap':
        context.go('/roadmap');
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY HEADER DELEGATE
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
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFF5F4FF),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$userName 👋',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
              ],
            ),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.violet, AppColors.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => true;
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
    final score = data.avgScore ?? 0;
    final scoreColor = score >= 80
        ? AppColors.emerald
        : score >= 60
            ? AppColors.amber
            : AppColors.rose;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF1E3A5F)]
              : [const Color(0xFF4C1D95), const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Score ring
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            score > 0 ? score.toInt().toString() : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          const Text(
                            'AVG',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Performance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.interviewsCompleted > 0
                          ? 'Based on ${data.interviewsCompleted} interviews'
                          : 'Start your first interview',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    if (data.bestStreak > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '${data.bestStreak} Day Streak',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                _statCell(
                    '${data.interviewCount}', 'Interviews', AppColors.violetLt),
                _vDivider(),
                _statCell(
                  data.bestScore != null
                      ? data.bestScore!.toInt().toString()
                      : '--',
                  'Best Score',
                  AppColors.emerald,
                ),
                _vDivider(),
                _statCell('${data.roadmapCount}', 'Roadmaps', AppColors.cyan),
                _vDivider(),
                _statCell('${data.resumeCount}', 'Resumes', AppColors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String val, String lbl, Color color) => Expanded(
        child: Column(
          children: [
            Text(val,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 2),
            Text(lbl,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 9, letterSpacing: 0.3),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _vDivider() => Container(
      width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12));
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
    final latest = trend.last.score;
    final prev = trend[trend.length - 2].score;
    final isUp = latest >= prev;
    final diff = (latest - prev).abs().toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Score Trend',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                ),
              ),
              const Spacer(),
              Icon(
                isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: isUp ? AppColors.emerald : AppColors.rose,
              ),
              const SizedBox(width: 4),
              Text(
                '$diff pts',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUp ? AppColors.emerald : AppColors.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _SparklinePainter(trend: trend, isDark: isDark),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: trend
                .take(math.min(5, trend.length))
                .map((t) => Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
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
    final scores = trend.map((t) => t.score).toList();
    final minS = scores.reduce(math.min);
    final maxS = scores.reduce(math.max);
    final range = (maxS - minS).clamp(1.0, 100.0);

    final points = <Offset>[];
    for (int i = 0; i < scores.length; i++) {
      final x = size.width * i / (scores.length - 1);
      final y = size.height - (size.height * (scores[i] - minS) / range);
      points.add(Offset(x, y.clamp(2.0, size.height - 2)));
    }

    // Fill
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
            AppColors.violet.withValues(alpha: 0.25),
            AppColors.violet.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Smooth curve
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 =
          Offset((points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.violet
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.violet);
      canvas.drawCircle(
        p,
        2,
        Paint()..color = isDark ? AppColors.darkSurface : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final String sub;
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkInk40 : AppColors.lightInk40),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge ?? sub,
              style: TextStyle(
                fontSize: 10,
                color: badge != null
                    ? gradient.first
                    : (isDark ? AppColors.darkInk40 : AppColors.lightInk40),
                fontWeight: badge != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE ROADMAP CARD
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
    final progress = roadmap.overallProgress / 100;
    final progressColor = progress >= 0.8
        ? AppColors.emerald
        : progress >= 0.5
            ? AppColors.violet
            : AppColors.amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'IN PROGRESS',
                    style: TextStyle(
                      color: AppColors.violet,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${roadmap.overallProgress.toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              roadmap.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              roadmap.targetRole,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 13,
                  color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                ),
                const SizedBox(width: 4),
                Text(
                  '${roadmap.milestonesDone}/${roadmap.milestonesTotal} milestones',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                  ),
                ),
                if (roadmap.streakDays > 0) ...[
                  const Spacer(),
                  const Text('🔥', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text(
                    '${roadmap.streakDays}d streak',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT INTERVIEW TILE
// ─────────────────────────────────────────────────────────────────────────────
class _InterviewTile extends StatelessWidget {
  final RecentInterview interview;
  final bool isDark;
  final VoidCallback onTap;

  const _InterviewTile({
    required this.interview,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = interview.score;
    final scoreColor = score == null
        ? Colors.grey
        : score >= 80
            ? AppColors.emerald
            : score >= 60
                ? AppColors.amber
                : AppColors.rose;

    final diffColor = interview.difficulty == 'hard'
        ? AppColors.rose
        : interview.difficulty == 'medium'
            ? AppColors.amber
            : AppColors.emerald;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: AppColors.violet, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interview.jobRole,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          interview.difficulty.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: diffColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(interview.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkInk40
                              : AppColors.lightInk40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (score != null)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    score.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: scoreColor,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('N/A',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    try {
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final DashboardTip tip;
  final bool isDark;

  const _TipCard({required this.tip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: isDark ? 0.15 : 0.07),
            AppColors.cyan.withValues(alpha: isDark ? 0.15 : 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(tip.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.body,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  Widget build(BuildContext context) {
    final color = _colorFor(item.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(item.icon), color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(item.time),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'mic':
        return Icons.mic_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'map':
        return Icons.route_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _colorFor(String color) {
    switch (color) {
      case 'purple':
        return AppColors.violetLt;
      case 'blue':
        return AppColors.cyan;
      case 'green':
        return AppColors.emerald;
      default:
        return AppColors.violet;
    }
  }

  String _formatTime(DateTime dt) {
    try {
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER (kept public for backward compat with any other file using it)
// ─────────────────────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? action;

  const _SectionHeader(this.title, {required this.isDark, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
              letterSpacing: 0.2,
            ),
          ),
          if (action != null) ...[const Spacer(), action!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILL CHIP (kept public for backward compat)
// ─────────────────────────────────────────────────────────────────────────────
class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.rose,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SKELETON  — animated shimmer
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatefulWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.65)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = widget.isDark
            ? Color.lerp(
                AppColors.darkSurface, AppColors.darkSurface2, _anim.value)!
            : Color.lerp(
                const Color(0xFFE5E7EB), const Color(0xFFF3F4F6), _anim.value)!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 56),
            _bone(160, c),
            const SizedBox(height: 12),
            _bone(86, c),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _bone(90, c)),
              const SizedBox(width: 10),
              Expanded(child: _bone(90, c)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _bone(90, c)),
              const SizedBox(width: 10),
              Expanded(child: _bone(90, c)),
            ]),
            const SizedBox(height: 20),
            _bone(100, c),
            const SizedBox(height: 12),
            _bone(68, c),
            const SizedBox(height: 8),
            _bone(68, c),
            const SizedBox(height: 8),
            _bone(68, c),
          ],
        );
      },
    );
  }

  Widget _bone(double h, Color c) => Container(
        height: h,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.rose),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not connect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Check your connection and try again',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
