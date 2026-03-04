// lib/features/roadmap/pages/roadmap_journey_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';
import '../services/roadmap_service.dart';
import '../../../services/api_service.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard

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

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: Stack(
        children: [
          // FIX 1: const + relative import
          const BackgroundPainter(),
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.violet))
              : state.roadmap == null
                  ? _buildError()
                  : _buildJourney(state.roadmap!, isDark),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.rose),
            const SizedBox(height: 16),
            const Text('Could not load roadmap',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => ref
                  .read(roadmapDetailProvider(widget.roadmapId).notifier)
                  .load(widget.roadmapId),
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.violet)),
            ),
          ],
        ),
      );

  Widget _buildJourney(Roadmap roadmap, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go('/roadmap'),
          ),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                // FIX 2: withOpacity → withValues
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          title: Text(roadmap.title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          actions: [
            IconButton(
              icon:
                  const Icon(Icons.analytics_rounded, color: AppColors.violet),
              onPressed: () => _showAnalytics(context, roadmap),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: _PremiumProgressHeader(roadmap: roadmap, isDark: isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _StageCard(
                stage: roadmap.stages[i],
                roadmapId: roadmap.id,
                isDark: isDark,
                svc: _svc,
                isLast: i == roadmap.stages.length - 1,
                onTaskToggled: () => ref
                    .read(roadmapDetailProvider(widget.roadmapId).notifier)
                    .load(widget.roadmapId),
              ),
              childCount: roadmap.stages.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Future<void> _showAnalytics(BuildContext context, Roadmap roadmap) async {
    // FIX: capture isDark before async gap to avoid BuildContext across async
    final isDarkLocal = Theme.of(context).brightness == Brightness.dark;
    final analytics = await _svc.getRoadmapAnalytics(roadmap.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _AnalyticsSheet(analytics: analytics, isDark: isDarkLocal),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumProgressHeader extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark;
  const _PremiumProgressHeader({required this.roadmap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: GlassCard(
        isDark: isDark,
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: roadmap.overallProgress / 100,
                    strokeWidth: 6,
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade200,
                    color: AppColors.violet,
                  ),
                ),
                Text('${roadmap.overallProgress.toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
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
                      '${roadmap.stages.length} Stages • ${roadmap.estimatedWeeks ?? "?"} Weeks',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StageCard extends StatefulWidget {
  final RoadmapStage stage;
  final int roadmapId;
  final bool isDark;
  final RoadmapService svc;
  final bool isLast;
  final VoidCallback onTaskToggled;

  const _StageCard({
    required this.stage,
    required this.roadmapId,
    required this.isDark,
    required this.svc,
    required this.isLast,
    required this.onTaskToggled,
  });

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand current unlocked & incomplete stage
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                // FIX 3: withOpacity → withValues (×4)
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
                    width: 2),
              ),
              child: Center(
                child: isLocked
                    ? const Icon(Icons.lock_rounded,
                        size: 14, color: Colors.grey)
                    : (stage.isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : Text(stage.icon ?? '📚',
                            style: const TextStyle(fontSize: 14))),
              ),
            ),
            if (!widget.isLast)
              // FIX 4: withOpacity → withValues
              Container(
                  width: 2,
                  height: 50,
                  color: Colors.grey.withValues(alpha: 0.2)),
          ],
        ),
        const SizedBox(width: 16),
        // Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: GlassCard(
              isDark: widget.isDark,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIX 5: InkWell with proper borderRadius to match GlassCard
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: isLocked
                        ? null
                        : () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('STAGE ${stage.order}',
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
                            ],
                          ),
                        ),
                        if (!isLocked)
                          Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: Colors.grey),
                      ],
                    ),
                  ),
                  if (_expanded && !isLocked) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.white10)),
                    ...stage.tasks.map((task) => _TaskTile(
                          task: task,
                          roadmapId: widget.roadmapId,
                          stageColor: color,
                          isDark: widget.isDark,
                          svc: widget.svc,
                          onToggled: widget.onTaskToggled,
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK TILE
// ─────────────────────────────────────────────────────────────────────────────
class _TaskTile extends StatefulWidget {
  final RoadmapTask task;
  final int roadmapId;
  final Color stageColor;
  final bool isDark;
  final RoadmapService svc;
  final VoidCallback onToggled;

  const _TaskTile({
    required this.task,
    required this.roadmapId,
    required this.stageColor,
    required this.isDark,
    required this.svc,
    required this.onToggled,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // FIX 6: withOpacity → withValues (×2)
        color: task.isCompleted
            ? AppColors.emerald.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
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
                // FIX 7: guard against re-checking a completed task
                // FIX 8: set _isLoading back to false after API call
                onChanged: task.isCompleted
                    ? null
                    : (v) async {
                        if (v != true) {
                          return;
                        }
                        setState(() => _isLoading = true);
                        await widget.svc
                            .completeTask(widget.roadmapId, task.id);
                        if (mounted) {
                          setState(() => _isLoading = false);
                          widget.onToggled();
                        }
                      },
              ),
        title: Text(task.title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: task.isCompleted
                    ? Colors.grey
                    : (widget.isDark ? Colors.white : Colors.black87),
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.library_books_rounded,
                    size: 16, color: AppColors.cyan),
                tooltip: 'Resources',
                onPressed: () => _showResources(context)),
            IconButton(
                icon: const Icon(Icons.timer_rounded,
                    size: 16, color: AppColors.amber),
                tooltip: 'Log Time',
                onPressed: () => _showTimer(context)),
          ],
        ),
      ),
    );
  }

  void _showResources(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResourcesSheet(
        task: widget.task,
        roadmapId: widget.roadmapId,
        svc: widget.svc,
        isDark: widget.isDark,
      ),
    );
  }

  void _showTimer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TimerSheet(
        task: widget.task,
        roadmapId: widget.roadmapId,
        svc: widget.svc,
        isDark: widget.isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOURCES SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ResourcesSheet extends StatefulWidget {
  final RoadmapTask task;
  final int roadmapId;
  final RoadmapService svc;
  final bool isDark;
  const _ResourcesSheet({
    required this.task,
    required this.roadmapId,
    required this.svc,
    required this.isDark,
  });
  @override
  State<_ResourcesSheet> createState() => _ResourcesSheetState();
}

class _ResourcesSheetState extends State<_ResourcesSheet> {
  List<Map<String, dynamic>> _resources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        await widget.svc.getTaskResources(widget.roadmapId, widget.task.id);
    if (mounted)
      setState(() {
        _resources = data;
        _loading = false;
      });
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_rounded;
      case 'course':
        return Icons.school_rounded;
      case 'docs':
        return Icons.description_rounded;
      default:
        return Icons.article_rounded;
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
      default:
        return AppColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
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
                child: Text(widget.task.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Learning Resources',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.cyan),
              )
            else if (_resources.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.library_books_outlined,
                        size: 48,
                        color: widget.isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    const Text('No resources yet',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Resources will appear here once added',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _resources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final r = _resources[i];
                    final type = r['type'] as String?;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _typeColor(type).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _typeColor(type).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _typeColor(type).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_typeIcon(type),
                                color: _typeColor(type), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['title'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: widget.isDark
                                            ? Colors.white
                                            : Colors.black87)),
                                if (r['description'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(r['description'],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          if (r['url'] != null)
                            Icon(Icons.open_in_new_rounded,
                                size: 16, color: _typeColor(type)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TimerSheet extends StatefulWidget {
  final RoadmapTask task;
  final int roadmapId;
  final RoadmapService svc;
  final bool isDark;
  const _TimerSheet({
    required this.task,
    required this.roadmapId,
    required this.svc,
    required this.isDark,
  });
  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  int _minutes = 25; // default Pomodoro
  bool _saving = false;

  Future<void> _log() async {
    setState(() => _saving = true);
    final ok = await widget.svc
        .logStudyTime(widget.roadmapId, widget.task.id, _minutes);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '⏱ $_minutes min logged for "${widget.task.title}"'
          : 'Failed to log time'),
      backgroundColor: ok ? Colors.green.shade600 : AppColors.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.timer_rounded, color: AppColors.amber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.task.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Log Study Time',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 32),
            // Big minute display
            Text('$_minutes min',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.amber)),
            const SizedBox(height: 8),
            const Text('How long did you study?',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            // Quick presets
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${m}m',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: selected ? Colors.white : AppColors.amber)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Slider for custom
            Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              activeColor: AppColors.amber,
              inactiveColor: AppColors.amber.withValues(alpha: 0.2),
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
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
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Log $_minutes Minutes',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANALYTICS SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AnalyticsSheet extends StatelessWidget {
  final Map<String, dynamic>? analytics;
  final bool isDark;
  const _AnalyticsSheet({required this.analytics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // FIX 9: withOpacity → withValues (×2)
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    // FIX 10: withOpacity → withValues
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Journey Analytics',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                    val: '${analytics?['completed_tasks'] ?? 0}', lbl: 'Done'),
                _Stat(
                    val: '${analytics?['total_logged_hours'] ?? 0}h',
                    lbl: 'Studied'),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String val, lbl;
  const _Stat({required this.val, required this.lbl});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(val,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.violet)),
          Text(lbl,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
        ],
      );
}
