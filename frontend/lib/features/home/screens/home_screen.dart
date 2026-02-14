// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/models/dashboard_model.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final dash = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      // SliverAppBar handles status bar padding correctly — no geometry errors
      body: RefreshIndicator(
        color: AppTheme.primary,
        strokeWidth: 2.5,
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: CustomScrollView(slivers: [
          // ── App bar (correct sliver type) ─────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 56,
            backgroundColor: AppTheme.bg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      gradient: AppTheme.brandGrad,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.psychology_alt_rounded,
                      color: Colors.white, size: 17)),
              const SizedBox(width: 9),
              const Text('Interview Prep',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.4)),
            ]),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppTheme.inkLight, size: 22),
                  onPressed: () =>
                      ref.read(dashboardProvider.notifier).refresh()),
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                      icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.elevate1,
                              border: Border.all(color: AppTheme.line)),
                          child: const Icon(Icons.logout_rounded,
                              size: 16, color: AppTheme.inkMid)),
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      })),
            ],
          ),

          // ── Content ───────────────────────────────────────
          if (dash.isLoading && !dash.hasData)
            const SliverToBoxAdapter(child: _Shimmer())
          else if (dash.error != null && !dash.hasData)
            SliverFillRemaining(
                child: _ErrorState(
                    onRetry: () =>
                        ref.read(dashboardProvider.notifier).refresh()))
          else if (dash.hasData)
            SliverToBoxAdapter(child: _Body(data: dash.data!, user: user))
          else
            const SliverToBoxAdapter(child: _Shimmer()),
        ]),
      ),
    );
  }
}

// ── Dashboard Body ────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final DashboardData data;
  final dynamic user;
  const _Body({required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final firstName = user?.fullName.split(' ').first as String? ?? 'there';
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? '☀️ Good morning'
        : hour < 17
            ? '👋 Good afternoon'
            : '🌙 Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),

        // ── Hero banner ──────────────────────────────────────
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: AppTheme.heroGrad,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppTheme.glowPrimary),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(greet,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      Text(firstName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                    ])),
                if (data.bestStreak > 0)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 3),
                        Text('${data.bestStreak}d',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ])),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                _heroStat('${data.interviewsCompleted}', 'Interviews'),
                _heroDivider(),
                _heroStat(
                    data.avgScore != null
                        ? data.avgScore!.toStringAsFixed(0)
                        : '—',
                    'Avg Score'),
                _heroDivider(),
                _heroStat('${data.roadmapCount}', 'Roadmaps'),
                _heroDivider(),
                _heroStat('${data.resumeCount}', 'Resumes'),
              ]),
            ])),
        const SizedBox(height: 20),

        // ── Tip card ─────────────────────────────────────────
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15))),
            child: Row(children: [
              Text(data.tip.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(data.tip.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.primary)),
                    const SizedBox(height: 2),
                    Text(data.tip.body,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.inkMid)),
                  ])),
            ])),
        const SizedBox(height: 20),

        // ── Quick actions ─────────────────────────────────────
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink)),
        const SizedBox(height: 12),
        Row(children: [
          _ActionChip(
              icon: Icons.add_rounded,
              label: 'New Interview',
              color: AppTheme.primary,
              route: '/interview'),
          const SizedBox(width: 10),
          _ActionChip(
              icon: Icons.upload_file_rounded,
              label: 'Upload Resume',
              color: AppTheme.accent,
              route: '/resumes'),
          const SizedBox(width: 10),
          _ActionChip(
              icon: Icons.map_rounded,
              label: 'Roadmap',
              color: AppTheme.success,
              route: '/roadmap'),
        ]),
        const SizedBox(height: 20),

        // ── Stats grid ───────────────────────────────────────
        const Text('Overview',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink)),
        const SizedBox(height: 12),
        GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: [
              _StatCard(
                  icon: Icons.description_rounded,
                  label: 'Resumes',
                  value: '${data.resumeCount}',
                  sub: '${data.resumeAnalyzed} analyzed',
                  color: AppTheme.accent),
              _StatCard(
                  icon: Icons.mic_rounded,
                  label: 'Interviews',
                  value: '${data.interviewCount}',
                  sub: '${data.interviewsCompleted} done',
                  color: AppTheme.primary),
              _StatCard(
                  icon: Icons.emoji_events_rounded,
                  label: 'Best Score',
                  value: data.bestScore != null
                      ? data.bestScore!.toStringAsFixed(0)
                      : '—',
                  sub: data.avgScore != null
                      ? 'avg ${data.avgScore!.toStringAsFixed(0)}'
                      : 'no data',
                  color: AppTheme.warning),
              _StatCard(
                  icon: Icons.map_rounded,
                  label: 'Roadmaps',
                  value: '${data.roadmapCount}',
                  sub: data.activeRoadmap != null ? '1 active' : 'none',
                  color: AppTheme.success),
            ]),

        // ── Active roadmap ───────────────────────────────────
        if (data.activeRoadmap != null) ...[
          const SizedBox(height: 20),
          const Text('Active Roadmap',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink)),
          const SizedBox(height: 12),
          _RoadmapCard(rm: data.activeRoadmap!),
        ],

        // ── Recent interviews ────────────────────────────────
        if (data.recentInterviews.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Recent Interviews',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink)),
          const SizedBox(height: 12),
          ...data.recentInterviews.take(3).map((iv) => _InterviewRow(iv: iv)),
        ],

        // ── Skill gaps ───────────────────────────────────────
        if (data.skillGaps.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Skills to Learn',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.skillGaps
                  .take(8)
                  .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3))),
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w600))))
                  .toList()),
        ],
      ]),
    );
  }

  Widget _heroStat(String v, String l) => Expanded(
          child: Column(children: [
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 19)),
        Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]));

  Widget _heroDivider() => Container(
      width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25));
}

// ── Action chip — uses Material InkWell (no mouse_tracker null bug) ──
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label, route;
  final Color color;
  const _ActionChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.route});

  @override
  Widget build(BuildContext ctx) => Expanded(
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => ctx.go(route),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.2))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: color,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ),
      );
}

// ── Stat card ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext ctx) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
          boxShadow: AppTheme.elevate1),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 15)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ]),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink)),
            Text(sub,
                style:
                    const TextStyle(fontSize: 10.5, color: AppTheme.inkLight)),
          ]));
}

// ── Roadmap card ─────────────────────────────────────────────────
class _RoadmapCard extends StatelessWidget {
  final ActiveRoadmapSummary rm;
  const _RoadmapCard({required this.rm});

  @override
  Widget build(BuildContext ctx) => Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => ctx.go('/roadmap/${rm.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3)),
                  boxShadow: AppTheme.elevate1),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.trending_up_rounded,
                              color: AppTheme.success, size: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(rm.targetRole,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                            Text(
                                '${rm.milestonesDone}/${rm.milestonesTotal} milestones',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.inkLight)),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.inkLight, size: 20),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                            value: rm.overallProgress / 100,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor:
                                const AlwaysStoppedAnimation(AppTheme.success),
                            minHeight: 7)),
                    const SizedBox(height: 6),
                    Text('${rm.overallProgress.toStringAsFixed(0)}% complete',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.inkLight)),
                  ])),
        ),
      );
}

// ── Interview row ────────────────────────────────────────────────
class _InterviewRow extends StatelessWidget {
  final RecentInterview iv;
  const _InterviewRow({required this.iv});

  @override
  Widget build(BuildContext ctx) {
    final scored = iv.score != null;
    final scoreColor = scored
        ? (iv.score! >= 80
            ? AppTheme.success
            : iv.score! >= 60
                ? AppTheme.warning
                : AppTheme.danger)
        : AppTheme.inkLight;

    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
            boxShadow: AppTheme.elevate1),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.mic_rounded,
                  color: AppTheme.primary, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(iv.jobRole,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('${iv.difficulty} • ${iv.status}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.inkLight)),
              ])),
          if (scored)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(iv.score!.toStringAsFixed(0),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                        fontSize: 13))),
        ]));
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────
class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext ctx) => Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF9FAFB),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _box(h: 148, r: 22),
            const SizedBox(height: 12),
            _box(h: 56, r: 14),
            const SizedBox(height: 20),
            _box(h: 14, w: 120),
            const SizedBox(height: 10),
            _box(h: 58),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _box(h: 90, r: 16)),
              const SizedBox(width: 12),
              Expanded(child: _box(h: 90, r: 16))
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _box(h: 90, r: 16)),
              const SizedBox(width: 12),
              Expanded(child: _box(h: 90, r: 16))
            ]),
            const SizedBox(height: 20),
            _box(h: 120, r: 16),
          ])));

  Widget _box({double h = 60, double? w, double r = 12}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(r)));
}

// ── Error state ───────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext ctx) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.wifi_off_rounded,
                    color: AppTheme.danger, size: 36)),
            const SizedBox(height: 16),
            const Text('Could not load dashboard',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Check your connection and try again',
                style: TextStyle(color: AppTheme.inkMid, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry')),
          ])));
}
