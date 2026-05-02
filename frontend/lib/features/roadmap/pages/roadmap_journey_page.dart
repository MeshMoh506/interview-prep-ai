//
// lib/features/roadmap/pages/roadmap_journey_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';
import '../services/roadmap_service.dart';
import '../../../services/api_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../goals/providers/goal_provider.dart'; // ← NEW

class RoadmapJourneyPage extends ConsumerStatefulWidget {
  final int roadmapId;
  const RoadmapJourneyPage({super.key, required this.roadmapId});
  @override
  ConsumerState<RoadmapJourneyPage> createState() => _RoadmapJourneyPageState();
}

class _RoadmapJourneyPageState extends ConsumerState<RoadmapJourneyPage> {
  late final RoadmapService _svc;

  @override
  void initState() {
    super.initState();
    _svc = RoadmapService(ApiService());
    Future.microtask(() => ref
        .read(roadmapDetailProvider(widget.roadmapId).notifier)
        .load(widget.roadmapId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roadmapDetailProvider(widget.roadmapId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        bottomNavigationBar: const AppBottomNav(currentIndex: 3),
        body: Stack(children: [
          const BackgroundPainter(),
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.violet))
              : state.roadmap == null
                  ? _buildError(s)
                  : _buildJourney(state.roadmap!, isDark, s),
        ]));
  }

  Widget _buildError(AppStrings s) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppColors.rose),
        const SizedBox(height: 16),
        Text(s.roadmapLoadFail,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        TextButton(
            onPressed: () => ref
                .read(roadmapDetailProvider(widget.roadmapId).notifier)
                .load(widget.roadmapId),
            child:
                Text(s.retry, style: const TextStyle(color: AppColors.violet))),
      ]));

  Widget _buildJourney(Roadmap roadmap, bool isDark, AppStrings s) =>
      CustomScrollView(slivers: [
        // ── App bar ────────────────────────────────────────────────────
        SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.go('/roadmap')),
            flexibleSpace: ClipRRect(
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.7)))),
            title: Text(roadmap.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.analytics_rounded,
                      color: AppColors.violet),
                  onPressed: () => _showAnalytics(context, roadmap, s)),
            ]),

        // ── Goal context banner ────────────────────────────────────────
        SliverToBoxAdapter(
          child: _GoalContextBanner(
            roadmapId: roadmap.id,
            isDark: isDark,
            isAr: Directionality.of(context) == TextDirection.rtl,
          ),
        ),

        // ── Progress header ────────────────────────────────────────────
        SliverToBoxAdapter(
            child:
                _PremiumProgressHeader(roadmap: roadmap, isDark: isDark, s: s)),

        // ── Stage list ─────────────────────────────────────────────────
        SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StageCard(
                        stage: roadmap.stages[i],
                        roadmapId: roadmap.id,
                        isDark: isDark,
                        svc: _svc,
                        s: s,
                        isLast: i == roadmap.stages.length - 1,
                        onTaskToggled: () => ref
                            .read(roadmapDetailProvider(widget.roadmapId)
                                .notifier)
                            .load(widget.roadmapId)),
                    childCount: roadmap.stages.length))),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ]);

  Future<void> _showAnalytics(
      BuildContext context, Roadmap roadmap, AppStrings s) async {
    final isDarkLocal = Theme.of(context).brightness == Brightness.dark;
    final analytics = await _svc.getRoadmapAnalytics(roadmap.id);
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _AnalyticsSheet(
            analytics: analytics, isDark: isDarkLocal, roadmap: roadmap, s: s));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOAL CONTEXT BANNER — shown at top if roadmap belongs to a goal
// ─────────────────────────────────────────────────────────────────────────────
class _GoalContextBanner extends ConsumerWidget {
  final int roadmapId;
  final bool isDark, isAr;
  const _GoalContextBanner({
    required this.roadmapId,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalProvider).goals;
    // Find a goal that has this roadmap linked
    final linkedGoal = goals.where((g) => g.roadmapId == roadmapId).firstOrNull;

    if (linkedGoal == null) return const SizedBox.shrink();

    final weekDone = linkedGoal.currentWeekCount ?? 0;
    final weekTarget = linkedGoal.weeklyInterviewTarget ?? 3;
    final onTrack = weekDone >= weekTarget;
    final trackColor = onTrack ? AppColors.emerald : AppColors.violet;

    return GestureDetector(
      onTap: () => context.push('/goals/${linkedGoal.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.flag_rounded, color: AppColors.violet, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  isAr
                      ? 'هذه الخارطة مرتبطة بهدف'
                      : 'This roadmap is linked to a goal',
                  style: const TextStyle(
                      color: AppColors.violet,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  linkedGoal.targetRole,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
          const SizedBox(width: 8),
          // Weekly progress pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$weekDone/$weekTarget',
              style: TextStyle(
                  color: trackColor, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isAr
                ? Icons.arrow_back_ios_rounded
                : Icons.arrow_forward_ios_rounded,
            color: AppColors.violet,
            size: 12,
          ),
        ]),
      ),
    );
  }
}

// ── PROGRESS HEADER ──────────────────────────────────────────────────────────
class _PremiumProgressHeader extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark;
  final AppStrings s;
  const _PremiumProgressHeader(
      {required this.roadmap, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: GlassCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Stack(alignment: Alignment.center, children: [
                SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                        value: roadmap.overallProgress / 100,
                        strokeWidth: 6,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.grey.shade200,
                        color: AppColors.violet)),
                Text('${roadmap.overallProgress.toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
              ]),
              const SizedBox(width: 20),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(roadmap.targetRole ?? 'Skill Path',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                        '${roadmap.stages.length} ${s.roadmapStages} • ${roadmap.estimatedWeeks ?? "?"} Weeks',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _miniStat('${roadmap.completedTasks}/${roadmap.totalTasks}',
                  s.roadmapTasks, AppColors.violet),
              const SizedBox(width: 8),
              _miniStat('${roadmap.completedStages}/${roadmap.stages.length}',
                  s.roadmapStages, AppColors.emerald),
              if (roadmap.difficulty != null) ...[
                const SizedBox(width: 8),
                _miniStat(roadmap.difficulty!.toUpperCase(), s.roadmapLevel,
                    AppColors.amber),
              ],
            ]),
          ])));

  Widget _miniStat(String value, String label, Color color) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 13)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ])));
}

// ── STAGE CARD ───────────────────────────────────────────────────────────────
class _StageCard extends StatefulWidget {
  final RoadmapStage stage;
  final int roadmapId;
  final bool isDark;
  final RoadmapService svc;
  final bool isLast;
  final VoidCallback onTaskToggled;
  final AppStrings s;
  const _StageCard({
    required this.stage,
    required this.roadmapId,
    required this.isDark,
    required this.svc,
    required this.isLast,
    required this.onTaskToggled,
    required this.s,
  });
  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.stage.isUnlocked && !widget.stage.isCompleted;
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.violet;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.violet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final isLocked = !stage.isUnlocked;
    final color = _parseColor(stage.color);
    final s = widget.s;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey.withValues(alpha: 0.1)
                    : (stage.isCompleted
                        ? AppColors.emerald
                        : color.withValues(alpha: 0.2)),
                shape: BoxShape.circle,
                border: Border.all(
                    color: isLocked
                        ? Colors.grey.withValues(alpha: 0.3)
                        : (stage.isCompleted ? AppColors.emerald : color),
                    width: 2)),
            child: Center(
                child: isLocked
                    ? const Icon(Icons.lock_rounded,
                        size: 14, color: Colors.grey)
                    : (stage.isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : Text(stage.icon ?? '📚',
                            style: const TextStyle(fontSize: 14))))),
        if (!widget.isLast)
          Container(
              width: 2, height: 50, color: Colors.grey.withValues(alpha: 0.2)),
      ]),
      const SizedBox(width: 16),
      Expanded(
          child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: GlassCard(
                  isDark: widget.isDark,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: isLocked
                            ? null
                            : () => setState(() => _expanded = !_expanded),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('${s.roadmapStage} ${stage.order}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: color,
                                              letterSpacing: 1)),
                                      Text(stage.title,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: isLocked
                                                  ? Colors.grey
                                                  : (widget.isDark
                                                      ? Colors.white
                                                      : Colors.black87))),
                                    ])),
                                if (!isLocked) ...[
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          '${stage.completedTaskCount}/${stage.totalTaskCount}',
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900))),
                                  const SizedBox(width: 8),
                                  Icon(
                                      _expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: Colors.grey),
                                ],
                              ]),
                              if (!isLocked && stage.totalTaskCount > 0) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                        value: stage.progress / 100,
                                        backgroundColor: Colors.white10,
                                        color: stage.isCompleted
                                            ? AppColors.emerald
                                            : color,
                                        minHeight: 4)),
                              ],
                            ])),
                    if (_expanded && !isLocked) ...[
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.white10)),
                      if (stage.description.isNotEmpty) ...[
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(stage.description,
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    height: 1.4))),
                        const SizedBox(height: 10),
                      ],
                      ...stage.tasks.map((task) => _TaskTile(
                          task: task,
                          roadmapId: widget.roadmapId,
                          stageColor: color,
                          isDark: widget.isDark,
                          svc: widget.svc,
                          s: s,
                          onToggled: widget.onTaskToggled)),
                    ],
                  ])))),
    ]);
  }
}

// ── TASK TILE ────────────────────────────────────────────────────────────────
class _TaskTile extends StatefulWidget {
  final RoadmapTask task;
  final int roadmapId;
  final Color stageColor;
  final bool isDark;
  final RoadmapService svc;
  final VoidCallback onToggled;
  final AppStrings s;
  const _TaskTile({
    required this.task,
    required this.roadmapId,
    required this.stageColor,
    required this.isDark,
    required this.svc,
    required this.onToggled,
    required this.s,
  });
  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final s = widget.s;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: task.isCompleted
                ? AppColors.emerald.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.emerald))
                : Checkbox(
                    value: task.isCompleted,
                    activeColor: AppColors.emerald,
                    onChanged: task.isCompleted
                        ? null
                        : (v) async {
                            if (v != true) return;
                            setState(() => _isLoading = true);
                            await widget.svc
                                .completeTask(widget.roadmapId, task.id);
                            if (mounted) {
                              setState(() => _isLoading = false);
                              widget.onToggled();
                            }
                          }),
            title: Text(task.title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? Colors.grey
                        : (widget.isDark ? Colors.white : Colors.black87),
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: task.estimatedHours > 0
                ? Text(
                    '${task.estimatedHours.toStringAsFixed(0)} ${s.roadmapHEstimated}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10))
                : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (task.resources.isNotEmpty)
                GestureDetector(
                    onTap: () => _showResources(context),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.library_books_rounded,
                              size: 12, color: AppColors.cyan),
                          const SizedBox(width: 3),
                          Text('${task.resources.length}',
                              style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ])))
              else
                IconButton(
                    icon: const Icon(Icons.library_books_rounded,
                        size: 16, color: AppColors.cyan),
                    tooltip: s.roadmapResources,
                    onPressed: () => _showResources(context)),
              IconButton(
                  icon: const Icon(Icons.timer_rounded,
                      size: 16, color: AppColors.amber),
                  tooltip: s.roadmapLogTime,
                  onPressed: () => _showTimer(context)),
            ])));
  }

  void _showResources(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResourcesSheet(
          task: widget.task, isDark: widget.isDark, s: widget.s));

  void _showTimer(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TimerSheet(
          task: widget.task,
          roadmapId: widget.roadmapId,
          svc: widget.svc,
          isDark: widget.isDark,
          s: widget.s));
}

// ── RESOURCES SHEET ───────────────────────────────────────────────────────────
class _ResourcesSheet extends StatelessWidget {
  final RoadmapTask task;
  final bool isDark;
  final AppStrings s;
  const _ResourcesSheet(
      {required this.task, required this.isDark, required this.s});

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_rounded;
      case 'course':
        return Icons.school_rounded;
      case 'docs':
        return Icons.description_rounded;
      case 'article':
        return Icons.article_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'video':
        return AppColors.rose;
      case 'course':
        return AppColors.violet;
      case 'docs':
        return AppColors.emerald;
      case 'article':
        return AppColors.cyan;
      default:
        return AppColors.amber;
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final canOpen = await canLaunchUrl(uri);
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${s.roadmapCouldNotOpen} $url'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resources = task.resources;
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.library_books_rounded,
                    color: AppColors.cyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(task.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      resources.isEmpty
                          ? s.roadmapNoResources
                          : '${resources.length} ${s.roadmapResources}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12))),
              const SizedBox(height: 16),
              if (resources.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Icons.library_books_outlined,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text(s.roadmapNoResources,
                          style: const TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(s.roadmapResourcesSub,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ]))
              else
                Flexible(
                    child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: resources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final r = resources[i];
                          final type = r['type'] as String?;
                          final url = r['url']?.toString() ?? '';
                          final hasUrl =
                              url.isNotEmpty && url.startsWith('http');
                          return GestureDetector(
                              onTap:
                                  hasUrl ? () => _openUrl(context, url) : null,
                              child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: _typeColor(type)
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: _typeColor(type)
                                              .withValues(alpha: 0.2))),
                                  child: Row(children: [
                                    Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                            color: _typeColor(type)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Icon(_typeIcon(type),
                                            color: _typeColor(type), size: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              r['title']?.toString() ??
                                                  'Resource',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87)),
                                          if (r['description'] != null &&
                                              r['description']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(r['description'].toString(),
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                          if (hasUrl) ...[
                                            const SizedBox(height: 4),
                                            Text(url,
                                                style: TextStyle(
                                                    color: _typeColor(type),
                                                    fontSize: 10),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                        ])),
                                    const SizedBox(width: 8),
                                    if (hasUrl)
                                      Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                              color: _typeColor(type)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Icon(Icons.open_in_new_rounded,
                                              size: 16,
                                              color: _typeColor(type)))
                                    else
                                      Icon(Icons.lock_outline_rounded,
                                          size: 16,
                                          color: Colors.grey
                                              .withValues(alpha: 0.4)),
                                  ])));
                        })),
              const SizedBox(height: 16),
            ])));
  }
}

// ── TIMER SHEET ───────────────────────────────────────────────────────────────
class _TimerSheet extends StatefulWidget {
  final RoadmapTask task;
  final int roadmapId;
  final RoadmapService svc;
  final bool isDark;
  final AppStrings s;
  const _TimerSheet(
      {required this.task,
      required this.roadmapId,
      required this.svc,
      required this.isDark,
      required this.s});
  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  int _minutes = 25;
  bool _saving = false;

  Future<void> _log() async {
    setState(() => _saving = true);
    final ok = await widget.svc
        .logStudyTime(widget.roadmapId, widget.task.id, _minutes);
    if (!mounted) return;
    Navigator.pop(context);
    final s = widget.s;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '⏱ $_minutes min logged for "${widget.task.title}"'
            : s.roadmapFailedLog),
        backgroundColor: ok ? Colors.green.shade600 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
            decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.timer_rounded,
                    color: AppColors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(widget.task.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.roadmapLogTime,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12))),
              const SizedBox(height: 32),
              Text('$_minutes min',
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.amber)),
              const SizedBox(height: 8),
              Text(s.roadmapHowLong,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [15, 25, 45, 60].map((m) {
                    final selected = _minutes == m;
                    return GestureDetector(
                        onTap: () => setState(() => _minutes = m),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.amber
                                    : AppColors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${m}m',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.amber))));
                  }).toList()),
              const SizedBox(height: 16),
              Slider(
                  value: _minutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  activeColor: AppColors.amber,
                  inactiveColor: AppColors.amber.withValues(alpha: 0.2),
                  onChanged: (v) => setState(() => _minutes = v.round())),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _saving ? null : _log,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('${s.roadmapLogMinutes} $_minutes min',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)))),
            ])));
  }
}

// ── ANALYTICS SHEET ──────────────────────────────────────────────────────────
class _AnalyticsSheet extends StatelessWidget {
  final Map<String, dynamic>? analytics;
  final bool isDark;
  final Roadmap roadmap;
  final AppStrings s;
  const _AnalyticsSheet(
      {required this.analytics,
      required this.isDark,
      required this.roadmap,
      required this.s});

  @override
  Widget build(BuildContext context) {
    final stages = (analytics?['stages'] as List?) ?? [];
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(s.roadmapAnalytics,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 24),
              Row(children: [
                _Stat(
                    val:
                        '${analytics?['completed_tasks'] ?? roadmap.completedTasks}',
                    lbl: s.roadmapTasksDone),
                _Stat(
                    val: '${analytics?['total_tasks'] ?? roadmap.totalTasks}',
                    lbl: s.roadmapTotalTasks2),
                _Stat(
                    val: '${analytics?['total_logged_hours'] ?? 0}h',
                    lbl: s.roadmapStudied),
                _Stat(
                    val: '${roadmap.overallProgress.toInt()}%',
                    lbl: s.roadmapProgress),
              ]),
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(s.roadmapStageProg,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.grey))),
                const SizedBox(height: 12),
                ...stages.map<Widget>((st) {
                  final progress = (st['progress'] as num?)?.toDouble() ?? 0;
                  Color stageColor = AppColors.violet;
                  try {
                    final hex = st['color']?.toString() ?? '';
                    if (hex.isNotEmpty) {
                      stageColor =
                          Color(int.parse(hex.replaceFirst('#', '0xFF')));
                    }
                  } catch (_) {}
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(st['title']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700))),
                              Text(
                                  '${st['completed_tasks'] ?? 0}/${st['total_tasks'] ?? 0}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: stageColor,
                                      fontWeight: FontWeight.w900)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                    value: progress / 100,
                                    backgroundColor: Colors.white10,
                                    color: stageColor,
                                    minHeight: 6)),
                          ]));
                }),
              ],
              const SizedBox(height: 16),
            ])));
  }
}

class _Stat extends StatelessWidget {
  final String val, lbl;
  const _Stat({required this.val, required this.lbl});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(val,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.violet)),
        const SizedBox(height: 2),
        Text(lbl,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500)),
      ]));
}
