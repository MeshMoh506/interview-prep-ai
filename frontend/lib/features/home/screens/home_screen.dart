import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hiq_card.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../providers/dashboard_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good morning,', style: Theme.of(context).textTheme.bodySmall),
            Text('Meshari 👋',
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
              child: const Center(
                child: Text('M',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        color: AppColors.violet,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Hero Card ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: HiqHeroBanner(
                borderColor:
                    isDark ? const Color(0x407C5CFC) : const Color(0x307C5CFC),
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
                                value: 0.78,
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
                                  Text('78',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  Text('SCORE',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
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
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text('Based on 12 interviews',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.15),
                                  border: Border.all(
                                      color: AppColors.amber
                                          .withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('🔥 7 Day Streak',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statCell(context, '12', 'Interviews',
                            AppColors.violetLt, isDark),
                        _divider(isDark),
                        _statCell(context, '85', 'Best Score',
                            AppColors.emerald, isDark),
                        _divider(isDark),
                        _statCell(
                            context, '3', 'Roadmaps', AppColors.cyan, isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick Actions ──────────────────────────────────
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
                      'Analyze & optimize',
                      Icons.description_outlined,
                      [AppColors.cyanDk, AppColors.cyan],
                      () => context.go('/resume'),
                      isDark),
                  _actionCard(
                      context,
                      'Learning Path',
                      'Personalized roadmap',
                      Icons.route_outlined,
                      [const Color(0xFF00C58A), AppColors.emerald],
                      () => context.go('/roadmap'),
                      isDark),
                  _actionCard(
                      context,
                      'Analytics',
                      'Track your growth',
                      Icons.show_chart_rounded,
                      [const Color(0xFFD4A017), AppColors.amber],
                      () {},
                      isDark),
                ],
              ),
            ),

            // ── Recent Activity ────────────────────────────────
            const SectionLabel('Recent Activity'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _activityItem(
                    context,
                    icon: Icons.mic_outlined,
                    iconColor: AppColors.violetLt,
                    iconBg: AppColors.violet.withValues(alpha: 0.12),
                    title: 'Software Engineer Interview',
                    meta: 'Technical · Medium · 2h ago',
                    score: '85',
                    scoreColor: AppColors.emerald,
                    isDark: isDark,
                    onTap: () => context.go('/interview/results'),
                  ),
                  const SizedBox(height: 8),
                  _activityItem(
                    context,
                    icon: Icons.description_outlined,
                    iconColor: AppColors.cyan,
                    iconBg: AppColors.cyan.withValues(alpha: 0.12),
                    title: 'Resume — Senior Dev CV.pdf',
                    meta: 'ATS Score: 82/100 · Yesterday',
                    score: '82',
                    scoreColor: AppColors.amber,
                    isDark: isDark,
                    onTap: () => context.go('/resume'),
                  ),
                  const SizedBox(height: 8),
                  _activityItem(
                    context,
                    icon: Icons.route_outlined,
                    iconColor: AppColors.emerald,
                    iconBg: AppColors.emerald.withValues(alpha: 0.12),
                    title: 'System Design Milestone',
                    meta: 'Roadmap · 65% complete',
                    score: '65%',
                    scoreColor: AppColors.amber,
                    isDark: isDark,
                    onTap: () => context.go('/roadmap'),
                  ),
                ],
              ),
            ),

            // ── Skills to Strengthen ───────────────────────────
            const SectionLabel('Skills to Strengthen'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _SkillChip('System Design', AppColors.rose),
                  SizedBox(width: 8),
                  _SkillChip('Kubernetes', AppColors.amber),
                  SizedBox(width: 8),
                  _SkillChip('GraphQL', AppColors.violetLt),
                  SizedBox(width: 8),
                  _SkillChip('AWS Lambda', AppColors.cyan),
                  SizedBox(width: 8),
                  _SkillChip('Redis', AppColors.emerald),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
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

  Widget _actionCard(
    BuildContext ctx,
    String title,
    String sub,
    IconData icon,
    List<Color> gradColors,
    VoidCallback onTap,
    bool isDark,
  ) {
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
                  color: isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                )),
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
    required String score,
    required Color scoreColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
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
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? AppColors.darkInk40 : AppColors.lightInk40,
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(score,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: scoreColor)),
            ],
          ),
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
