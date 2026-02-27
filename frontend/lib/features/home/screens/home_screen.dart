// lib/features/home/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _HeroCard(data: data, isDark: isDark),
          ),
        ),
        if (data.scoreTrend.length >= 2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _SparklineCard(trend: data.scoreTrend, isDark: isDark),
            ),
          ),
        SliverToBoxAdapter(
          child: _SectionHeader('QUICK ACTIONS', isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              _ActionCard(
                title: 'Interview',
                sub: 'AI Mock Session',
                icon: Icons.mic_rounded,
                gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
                gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
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
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                onTap: () => context.go('/roadmap'),
                isDark: isDark,
              ),
              _ActionCard(
                title: 'Profile',
                sub: 'Settings & stats',
                icon: Icons.person_rounded,
                gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: () => context.go('/profile'),
                isDark: isDark,
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
            child: _SectionHeader('ACTIVE ROADMAP', isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _RoadmapCard(
                roadmap: data.activeRoadmap!,
                isDark: isDark,
                onTap: () => context.go('/roadmap/${data.activeRoadmap!.id}'),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: _SectionHeader('RECENT ACTIVITY', isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActivityTile(
                  item: data.activityFeed[i],
                  isDark: isDark,
                  onTap: () {},
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
// HEADER DELEGATE
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
                    'Good Day,',
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
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final DashboardData data;
  final bool isDark;
  const _HeroCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              _CircularScore(score: score),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${data.interviewsCompleted} sessions completed',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroStat(val: '${data.interviewCount}', label: 'Interviews'),
              _HeroStat(val: '${data.resumeCount}', label: 'Resumes'),
              _HeroStat(val: '${data.roadmapCount}', label: 'Roadmaps'),
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '${score.toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String val, label;
  const _HeroStat({required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradient[0],
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    roadmap.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${roadmap.overallProgress.toInt()}%',
                  style: const TextStyle(
                    color: AppColors.violet,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${roadmap.milestonesDone}/${roadmap.milestonesTotal} milestones · '
              '${roadmap.streakDays} day streak 🔥',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
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
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.violet,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isUp ? Colors.green : Colors.redAccent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: isUp ? Colors.green : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUp ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: _SparklinePainter(trend: trend, isDark: isDark),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          // Date range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trend.isNotEmpty ? trend.first.date : '',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              Text(
                trend.isNotEmpty ? trend.last.date : '',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
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

    final scores = trend.map((e) => e.score).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = (maxScore - minScore).clamp(1.0, double.infinity);

    // Build path points
    final points = List.generate(trend.length, (i) {
      final x = i / (trend.length - 1) * size.width;
      final y = size.height -
          ((scores[i] - minScore) / range) * size.height * 0.85 -
          size.height * 0.075;
      return Offset(x, y);
    });

    // Gradient fill under the line
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.violet.withValues(alpha: isDark ? 0.25 : 0.15),
          AppColors.violet.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Smooth line using cubic bezier
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i].dy,
      );
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }

    final linePaint = Paint()
      ..color = AppColors.violet
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Dot at the last point
    final dotPaint = Paint()..color = AppColors.violet;
    canvas.drawCircle(points.last, 4, dotPaint);
    final dotInner = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white;
    canvas.drawCircle(points.last, 2, dotInner);
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.violet.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _ErrorBody({this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error ?? 'An unexpected error occurred',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try Again',
              style: TextStyle(
                color: AppColors.violet,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
