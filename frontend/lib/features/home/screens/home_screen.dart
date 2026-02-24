import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hiq_card.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '/../shared/widgets/app_bottom_nav.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);

    // Get user name
    final userName = authState.user?.fullName.split(' ').first ?? 'User';

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      appBar: AppBar(
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getGreeting(), style: Theme.of(context).textTheme.bodySmall),
            Text('$userName 🫸',
                style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.violet, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: dashState.isLoading && dashState.data == null
          ? _buildLoadingSkeleton(isDark)
          : RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              color: AppColors.violet,
              child: dashState.data != null
                  ? _buildDashboard(context, ref, dashState.data!, isDark)
                  : _buildError(context, ref, dashState.error),
            ),
      // bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  Widget _buildDashboard(
      BuildContext context, WidgetRef ref, data, bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Hero Card with real scores ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: HiqHeroBanner(
            child: Column(
              children: [
                Row(
                  children: [
                    // Score ring
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (data.avgScore ?? 0) / 100,
                            strokeWidth: 5,
                            backgroundColor: isDark
                                ? AppColors.darkSurface3
                                : AppColors.lightSurface3,
                            color: AppColors.violet,
                            strokeCap: StrokeCap.round,
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data.avgScore != null
                                    ? data.avgScore!.toInt().toString()
                                    : '--',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text('SCORE',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall Performance',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            data.interviewsCompleted > 0
                                ? 'Based on ${data.interviewsCompleted} interviews'
                                : 'No interviews yet',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (data.bestStreak > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.15),
                                border: Border.all(
                                    color:
                                        AppColors.amber.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '🔥 ${data.bestStreak} Day Streak',
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statCell(context, '${data.interviewCount}', 'Interviews',
                        AppColors.violetLt, isDark),
                    _divider(isDark),
                    _statCell(
                        context,
                        data.bestScore != null
                            ? data.bestScore!.toInt().toString()
                            : '--',
                        'Best Score',
                        AppColors.emerald,
                        isDark),
                    _divider(isDark),
                    _statCell(context, '${data.roadmapCount}', 'Roadmaps',
                        AppColors.cyan, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Motivational Tip ───────────────────────────────────
        if (data.tip.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.violet.withValues(alpha: 0.1),
                    AppColors.cyan.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppColors.violet.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(data.tip.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.tip.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.tip.body,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkInk40
                                : AppColors.lightInk40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Quick Actions ──────────────────────────────────────
        const SectionLabel('Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _actionCard(
                  context,
                  'Start Interview',
                  'AI-powered mock session',
                  Icons.mic_outlined,
                  [AppColors.violet, AppColors.violetDk],
                  () => context.go('/interview'),
                  isDark),
              _actionCard(
                  context,
                  'My Resumes',
                  '${data.resumeCount} uploaded',
                  Icons.description_outlined,
                  [AppColors.cyanDk, AppColors.cyan],
                  () => context.go('/resume'),
                  isDark),
              _actionCard(
                  context,
                  'Learning Path',
                  data.activeRoadmap != null
                      ? '${data.activeRoadmap!.overallProgress.toInt()}% complete'
                      : 'Create roadmap',
                  Icons.route_outlined,
                  [const Color(0xFF00C58A), AppColors.emerald],
                  () => context.go('/roadmap'),
                  isDark),
              _actionCard(
                  context,
                  'Analytics',
                  '${data.interviewsCompleted} completed',
                  Icons.show_chart_rounded,
                  [const Color(0xFFD4A017), AppColors.amber],
                  () {},
                  isDark),
            ],
          ),
        ),

        // ── Recent Activity ────────────────────────────────────
        if (data.activityFeed.isNotEmpty) ...[
          const SectionLabel('Recent Activity'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: data.activityFeed.take(5).map<Widget>((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _activityItem(
                    context,
                    icon: _getIconFromString(item.icon),
                    iconColor: _getColorFromString(item.color),
                    iconBg:
                        _getColorFromString(item.color).withValues(alpha: 0.12),
                    title: item.title,
                    meta: item.subtitle,
                    timestamp: _formatTime(item.time),
                    isDark: isDark,
                    onTap: () => _handleActivityTap(context, item.type),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Skills to Strengthen ───────────────────────────────
        if (data.skillGaps.isNotEmpty) ...[
          const SectionLabel('Skills to Strengthen'),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.skillGaps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _SkillChip(
                data.skillGaps[i],
                AppColors.rose,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final shimmerColor =
        isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: List.generate(
              4,
              (_) => Container(
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  )),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.rose),
            const SizedBox(height: 16),
            Text(
              error ?? 'Failed to load dashboard',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  IconData _getIconFromString(String icon) {
    switch (icon) {
      case 'mic':
        return Icons.mic_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'map':
        return Icons.route_outlined;
      default:
        return Icons.circle;
    }
  }

  Color _getColorFromString(String color) {
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

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
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

  Widget _statCell(
      BuildContext ctx, String val, String lbl, Color color, bool isDark) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(val,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            const SizedBox(height: 2),
            Text(lbl,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        isDark ? AppColors.darkInk40 : AppColors.lightInk40)),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => SizedBox(
        width: 10,
        child: VerticalDivider(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      );

  Widget _actionCard(BuildContext ctx, String title, String sub, IconData icon,
      List<Color> gradColors, VoidCallback onTap, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradColors),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const Spacer(),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        isDark ? AppColors.darkInk40 : AppColors.lightInk40)),
          ],
        ),
      ),
    );
  }

  Widget _activityItem(
    BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String meta,
    required String timestamp,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink40 = isDark ? AppColors.darkInk40 : AppColors.lightInk40;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(fontSize: 11, color: ink40)),
              ],
            ),
          ),
          Text(timestamp,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11, color: ink40)),
        ]),
      ),
    );
  }

  BottomNavigationBar _buildBottomNav(BuildContext ctx, int index) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (i) {
        const routes = [
          '/home',
          '/interview',
          '/resume',
          '/roadmap',
          '/profile'
        ];
        if (i < routes.length) ctx.go(routes[i]);
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.mic_none_rounded),
            activeIcon: Icon(Icons.mic_rounded),
            label: 'Interview'),
        BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description_rounded),
            label: 'Resume'),
        BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route_rounded),
            label: 'Roadmap'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile'),
      ],
    );
  }
}

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

class _SkillChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SkillChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
