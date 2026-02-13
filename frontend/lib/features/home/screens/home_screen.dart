// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../roadmap/providers/roadmap_provider.dart';
import '../../roadmap/models/roadmap_model.dart'; // ← fixed: explicit import

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.psychology, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          const Text('Interview Prep AI',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () => ref.read(dashboardStatsProvider.notifier).load(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardStatsProvider.notifier).load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Welcome ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Text(user?.fullName[0].toUpperCase() ?? 'U',
                        style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'Hello, ${user?.fullName.split(' ').first ?? 'there'}! 👋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                      const Text('Ready to level up today?',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    ])),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Live Stats ────────────────────────────────────────
            if (stats.isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()))
            else if (stats.stats != null)
              _StatsRow(stats: stats.stats!),
            const SizedBox(height: 20),

            // ── Active Roadmap banner ──────────────────────────────
            if (stats.stats?.activeRoadmap != null) ...[
              _ActiveRoadmapBanner(roadmap: stats.stats!.activeRoadmap!),
              const SizedBox(height: 20),
            ],

            // ── Feature Cards ──────────────────────────────────────
            Text('Features',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _FeatureCard(
                    icon: Icons.description_outlined,
                    title: 'Resume',
                    subtitle: 'Build & optimize',
                    color: Colors.blue,
                    badge: '✅ Ready',
                    onTap: () => context.go('/resumes')),
                _FeatureCard(
                    icon: Icons.psychology_outlined,
                    title: 'AI Interview',
                    subtitle: 'Practice with AI',
                    color: Colors.purple,
                    badge: '✅ Ready',
                    onTap: () => context.go('/interview')),
                _FeatureCard(
                    icon: Icons.map_outlined,
                    title: 'Skill Roadmap',
                    subtitle: 'Personalized path',
                    color: Colors.green,
                    badge: '✅ Ready',
                    onTap: () => context.go('/roadmap')),
                _FeatureCard(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics',
                    subtitle: 'Track progress',
                    color: Colors.orange,
                    badge: '🔜 Soon',
                    onTap: () => _snack(context, 'Analytics')),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _snack(BuildContext ctx, String f) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('$f coming soon! 🚀'),
          behavior: SnackBarBehavior.floating));
}

// ── Stats Row ────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final DashboardStats stats; // ← now resolved via explicit import
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _StatCard(
                icon: Icons.description,
                label: 'Resumes',
                value: '${stats.resumesCount}',
                color: Colors.blue)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                icon: Icons.mic,
                label: 'Interviews',
                value: '${stats.interviewsCompleted}',
                color: Colors.purple)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                icon: Icons.star,
                label: 'Avg Score',
                value: stats.avgInterviewScore != null
                    ? stats.avgInterviewScore!.toStringAsFixed(0)
                    : '—',
                color: Colors.orange)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: stats.bestStreak > 0 ? '${stats.bestStreak}🔥' : '—',
                color: Colors.red)),
      ]);
}

// ── Active Roadmap Banner ─────────────────────────────────────────
class _ActiveRoadmapBanner extends StatelessWidget {
  final RoadmapModel roadmap; // ← now resolved via explicit import
  const _ActiveRoadmapBanner({required this.roadmap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.go('/roadmap/${roadmap.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.trending_up,
                    color: Colors.green, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Active: ${roadmap.targetRole}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                      value: roadmap.overallProgress / 100,
                      backgroundColor: Colors.green.shade100,
                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                      minHeight: 6),
                  const SizedBox(height: 3),
                  Text(
                      '${roadmap.overallProgress.toStringAsFixed(0)}% complete',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade700)),
                ])),
            const Icon(Icons.chevron_right, color: Colors.green),
          ]),
        ),
      );
}

// ── Feature Card ─────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, badge;
  final Color color;
  final VoidCallback onTap;
  const _FeatureCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.badge,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 28, color: color)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 3),
              Text(badge, style: const TextStyle(fontSize: 10)),
            ]),
          ),
        ),
      );
}

// ── Stat Card ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ]),
      );
}
