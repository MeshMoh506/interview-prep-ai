import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../auth/providers/auth_provider.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Interview Prep AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go("/login");
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user?.fullName[0].toUpperCase() ?? "U",
                      style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text("Welcome back!",
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(user?.fullName ?? "User",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(user?.email ?? "",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600])),
                      ])),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text("Features",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _FeatureCard(
                  icon: Icons.description_outlined,
                  title: "Resume Builder",
                  subtitle: "Create & optimize",
                  color: Colors.blue,
                  badge: "✅ Ready",
                  onTap: () => context.go("/resumes"), // ← fixed path
                ),
                _FeatureCard(
                  icon: Icons.psychology_outlined,
                  title: "AI Interview",
                  subtitle: "Practice with AI",
                  color: Colors.purple,
                  badge: "✅ Ready",
                  onTap: () => context.go("/interview"), // ← now working
                ),
                _FeatureCard(
                  icon: Icons.school_outlined,
                  title: "Skill Roadmap",
                  subtitle: "Learn & improve",
                  color: Colors.green,
                  badge: "🔜 Soon",
                  onTap: () => _snack(context, "Skill Roadmap"),
                ),
                _FeatureCard(
                  icon: Icons.analytics_outlined,
                  title: "Analytics",
                  subtitle: "Track progress",
                  color: Colors.orange,
                  badge: "🔜 Soon",
                  onTap: () => _snack(context, "Analytics"),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("Quick Stats",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      icon: Icons.description,
                      label: "Resumes",
                      value: "—",
                      color: Colors.blue)),
              const SizedBox(width: 16),
              Expanded(
                  child: _StatCard(
                      icon: Icons.mic,
                      label: "Interviews",
                      value: "—",
                      color: Colors.purple)),
              const SizedBox(width: 16),
              Expanded(
                  child: _StatCard(
                      icon: Icons.star,
                      label: "Avg Score",
                      value: "—",
                      color: Colors.orange)),
            ]),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String f) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$f coming soon! 🚀"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
}

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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 32, color: color)),
              const SizedBox(height: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(badge, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
}

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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
        ),
      );
}
