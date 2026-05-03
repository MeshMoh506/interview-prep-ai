// lib/features/roadmap/pages/roadmap_journey_page.dart
//
// ★ SKILL TREE redesign — like an RPG progression system:
//   • Stages = hexagonal/circular nodes connected by glowing lines
//   • Completed = green glow  |  Active = violet glow  |  Locked = dim grey
//   • Tap a stage node → expands tasks panel slides up from bottom
//   • Tasks in bottom sheet: checkable, resources, "Ask Coach" button
//   • Header: back + title + progress ring + analytics
//   • Matches design system: no BackgroundPainter, no GlassCard

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../models/roadmap_model.dart';
import '../providers/roadmap_provider.dart';
import '../services/roadmap_service.dart';
import '../../../services/api_service.dart';
import '../../coach/providers/coach_provider.dart';

class RoadmapJourneyPage extends ConsumerStatefulWidget {
  final int roadmapId;
  const RoadmapJourneyPage({super.key, required this.roadmapId});
  @override
  ConsumerState<RoadmapJourneyPage> createState() => _RoadmapJourneyPageState();
}

class _RoadmapJourneyPageState extends ConsumerState<RoadmapJourneyPage> {
  late final RoadmapService _svc;
  int? _selectedStageIndex;

  @override
  void initState() {
    super.initState();
    _svc = RoadmapService(ApiService());
    Future.microtask(() => ref
        .read(roadmapDetailProvider(widget.roadmapId).notifier)
        .load(widget.roadmapId));
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.violet;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.violet;
    }
  }

  void _openTaskSheet(BuildContext context, RoadmapStage stage, Roadmap roadmap,
      bool isDark, bool isAr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSheet(
        stage: stage,
        roadmapId: roadmap.id,
        svc: _svc,
        isDark: isDark,
        isAr: isAr,
        onTaskToggled: () {
          ref
              .read(roadmapDetailProvider(widget.roadmapId).notifier)
              .load(widget.roadmapId);
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              openTaskSheet(context, stage, roadmap, isDark, isAr);
            }
          });
        },
        onAskCoach: (taskTitle, taskDesc) {
          Navigator.pop(context);
          final ctx =
              '${isAr ? "مهمة: " : "Task: "}$taskTitle${taskDesc.isNotEmpty ? "\n$taskDesc" : ""}';
          ref
              .read(coachSessionProvider.notifier)
              .startSession(taskContext: ctx);
          context.push('/coach/chat');
        },
      ),
    );
  }

  // Public method so the sheet can call reload
  void openTaskSheet(BuildContext context, RoadmapStage stage, Roadmap roadmap,
      bool isDark, bool isAr) {
    _openTaskSheet(context, stage, roadmap, isDark, isAr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roadmapDetailProvider(widget.roadmapId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.violet))
          : state.roadmap == null
              ? _buildError(isDark, isAr)
              : _buildTree(state.roadmap!, isDark, isAr),
    );
  }

  Widget _buildError(bool isDark, bool isAr) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.rose),
          const SizedBox(height: 16),
          Text(isAr ? 'فشل التحميل' : 'Failed to load',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => ref
                .read(roadmapDetailProvider(widget.roadmapId).notifier)
                .load(widget.roadmapId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(isAr ? 'إعادة' : 'Retry',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  Widget _buildTree(Roadmap roadmap, bool isDark, bool isAr) {
    final stages = roadmap.stages;
    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _TreeHeader(
            roadmap: roadmap,
            isDark: isDark,
            isAr: isAr,
            onBack: () => context.go('/roadmap'),
            onAnalytics: () => _showAnalytics(context, roadmap, isDark, isAr),
          ),
        ),

        // ── Progress strip ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _ProgressStrip(roadmap: roadmap, isDark: isDark, isAr: isAr),
          ),
        ),

        // ── Skill tree ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SkillTree(
              stages: stages,
              isDark: isDark,
              isAr: isAr,
              parseColor: _parseColor,
              onStageTap: (stage) =>
                  _openTaskSheet(context, stage, roadmap, isDark, isAr),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  Future<void> _showAnalytics(
      BuildContext context, Roadmap roadmap, bool isDark, bool isAr) async {
    final analytics = await _svc.getRoadmapAnalytics(roadmap.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnalyticsSheet(
          analytics: analytics, isDark: isDark, isAr: isAr, roadmap: roadmap),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TREE HEADER — matches design system header
// ══════════════════════════════════════════════════════════════════
class _TreeHeader extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark, isAr;
  final VoidCallback onBack, onAnalytics;
  const _TreeHeader({
    required this.roadmap,
    required this.isDark,
    required this.isAr,
    required this.onBack,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final pct = roadmap.overallProgress.toInt();
    final color = pct >= 80
        ? AppColors.emerald
        : pct >= 40
            ? AppColors.violet
            : AppColors.amber;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onBack();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(
                isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                size: 22,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.70)
                    : Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        const SizedBox(width: 12),
        // Title
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(roadmap.targetRole ?? roadmap.title,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
                '${roadmap.stages.length} ${isAr ? "مراحل" : "stages"} • '
                '${roadmap.completedTasks}/${roadmap.totalTasks} ${isAr ? "مهمة" : "tasks"}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.40)
                        : Colors.black.withValues(alpha: 0.38))),
          ]),
        ),
        const SizedBox(width: 10),
        // Progress ring
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(
              value: (roadmap.overallProgress / 100).clamp(0.0, 1.0),
              strokeWidth: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: Text('$pct%',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        // Analytics
        GestureDetector(
          onTap: onAnalytics,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.analytics_rounded,
                size: 20, color: AppColors.violet),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PROGRESS STRIP — linear overall progress bar
// ══════════════════════════════════════════════════════════════════
class _ProgressStrip extends StatelessWidget {
  final Roadmap roadmap;
  final bool isDark, isAr;
  const _ProgressStrip(
      {required this.roadmap, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final pct = roadmap.overallProgress.toInt();
    final color = pct >= 80
        ? AppColors.emerald
        : pct >= 40
            ? AppColors.violet
            : AppColors.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Text(
            isAr ? 'التقدم الكلي' : 'Overall Progress',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.50)),
          ),
          const Spacer(),
          Text('$pct%',
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: roadmap.overallProgress / 100),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniStat('${roadmap.completedTasks}',
                isAr ? 'مهمة مكتملة' : 'Tasks Done', AppColors.emerald, isDark),
            _MiniStat(
                '${roadmap.completedStages}',
                isAr ? 'مرحلة مكتملة' : 'Stages Done',
                AppColors.violet,
                isDark),
            _MiniStat('${roadmap.estimatedWeeks ?? "?"}',
                isAr ? 'أسبوع' : 'Weeks', AppColors.amber, isDark),
          ],
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String val, label;
  final Color color;
  final bool isDark;
  const _MiniStat(this.val, this.label, this.color, this.isDark);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35))),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// SKILL TREE — the main visual
// Alternating left/right zigzag layout with connecting lines
// Each node = stage; tap opens task sheet
// ══════════════════════════════════════════════════════════════════
class _SkillTree extends StatelessWidget {
  final List<RoadmapStage> stages;
  final bool isDark, isAr;
  final Color Function(String?) parseColor;
  final void Function(RoadmapStage) onStageTap;
  const _SkillTree({
    required this.stages,
    required this.isDark,
    required this.isAr,
    required this.parseColor,
    required this.onStageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(stages.length, (i) {
        final stage = stages[i];
        final isLeft = i.isEven;
        final isLast = i == stages.length - 1;
        final color = parseColor(stage.color);
        final isLocked = !stage.isUnlocked;
        final isDone = stage.isCompleted;

        return Column(children: [
          // Node row — alternates left/right
          Row(
            mainAxisAlignment:
                isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (!isLeft) ...[
                // Info card (right-aligned nodes)
                Expanded(
                  child: _StageInfoCard(
                    stage: stage,
                    color: color,
                    isDark: isDark,
                    isAr: isAr,
                    alignRight: true,
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Stage node
              GestureDetector(
                onTap: isLocked
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onStageTap(stage);
                      },
                child: _StageNode(
                  stage: stage,
                  color: color,
                  isDark: isDark,
                  isLocked: isLocked,
                  isDone: isDone,
                ),
              ),

              if (isLeft) ...[
                const SizedBox(width: 16),
                // Info card (left-aligned nodes)
                Expanded(
                  child: _StageInfoCard(
                    stage: stage,
                    color: color,
                    isDark: isDark,
                    isAr: isAr,
                    alignRight: false,
                  ),
                ),
              ],
            ],
          ),

          // Connector — zigzag line to next node
          if (!isLast)
            _Connector(
              fromLeft: isLeft,
              color:
                  isDone ? AppColors.emerald : (isLocked ? Colors.grey : color),
              isDark: isDark,
            ),
        ]);
      }),
    );
  }
}

// ── Stage Node — the circle in the skill tree ──────────────────
class _StageNode extends StatelessWidget {
  final RoadmapStage stage;
  final Color color;
  final bool isDark, isLocked, isDone;
  const _StageNode({
    required this.stage,
    required this.color,
    required this.isDark,
    required this.isLocked,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final nodeColor = isLocked
        ? Colors.grey
        : isDone
            ? AppColors.emerald
            : color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLocked
            ? (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04))
            : nodeColor.withValues(alpha: 0.12),
        border: Border.all(
          color: isLocked ? Colors.grey.withValues(alpha: 0.25) : nodeColor,
          width: isDone ? 3 : 2,
        ),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: nodeColor.withValues(alpha: isDone ? 0.35 : 0.22),
                  blurRadius: isDone ? 20 : 12,
                  spreadRadius: isDone ? 2 : 0,
                ),
              ],
      ),
      child: Center(
        child: isLocked
            ? Icon(Icons.lock_rounded,
                size: 24, color: Colors.grey.withValues(alpha: 0.40))
            : isDone
                ? const Icon(Icons.check_rounded,
                    size: 32, color: AppColors.emerald)
                : Text(
                    stage.icon ?? '📚',
                    style: const TextStyle(fontSize: 28),
                  ),
      ),
    );
  }
}

// ── Stage Info Card ─────────────────────────────────────────────
class _StageInfoCard extends StatelessWidget {
  final RoadmapStage stage;
  final Color color;
  final bool isDark, isAr, alignRight;
  const _StageInfoCard({
    required this.stage,
    required this.color,
    required this.isDark,
    required this.isAr,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !stage.isUnlocked;
    final cardColor = isLocked
        ? Colors.grey
        : stage.isCompleted
            ? AppColors.emerald
            : color;

    return AnimatedOpacity(
      opacity: isLocked ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: cardColor.withValues(alpha: isLocked ? 0.10 : 0.20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Stage label
            Text(
              '${isAr ? "المرحلة" : "Stage"} ${stage.order}',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: cardColor),
            ),
            const SizedBox(height: 3),
            Text(
              stage.title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20)),
              maxLines: 2,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 6),
            // Progress bar
            if (!isLocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (stage.progress / 100).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: cardColor.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation(cardColor),
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Task count
            Text(
              '${stage.completedTaskCount}/${stage.totalTaskCount} ${isAr ? "مهمة" : "tasks"}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cardColor.withValues(alpha: 0.80)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connector line between nodes ───────────────────────────────
class _Connector extends StatelessWidget {
  final bool fromLeft, isDark;
  final Color color;
  const _Connector({
    required this.fromLeft,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: CustomPaint(
          painter: _ConnectorPainter(fromLeft: fromLeft, color: color),
          size: Size(MediaQuery.of(context).size.width - 40, 48),
        ),
      );
}

class _ConnectorPainter extends CustomPainter {
  final bool fromLeft;
  final Color color;
  _ConnectorPainter({required this.fromLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Node center X positions (36 = half of 72px node)
    final leftX = 36.0;
    final rightX = size.width - 36.0;

    final startX = fromLeft ? leftX : rightX;
    final endX = fromLeft ? rightX : leftX;

    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(
        startX,
        size.height * 0.4,
        endX,
        size.height * 0.6,
        endX,
        size.height,
      );

    canvas.drawPath(path, paint);

    // Arrow tip
    final arrowPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final tipX = endX;
    final tipY = size.height;
    canvas.drawLine(Offset(tipX - 6, tipY - 8), Offset(tipX, tipY), arrowPaint);
    canvas.drawLine(Offset(tipX + 6, tipY - 8), Offset(tipX, tipY), arrowPaint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fromLeft != fromLeft || old.color != color;
}

// ══════════════════════════════════════════════════════════════════
// TASK SHEET — slides up from bottom when stage is tapped
// Shows all tasks with checkbox, resources, Ask Coach button
// ══════════════════════════════════════════════════════════════════
class _TaskSheet extends StatefulWidget {
  final RoadmapStage stage;
  final int roadmapId;
  final RoadmapService svc;
  final bool isDark, isAr;
  final VoidCallback onTaskToggled;
  final void Function(String title, String desc) onAskCoach;
  const _TaskSheet({
    required this.stage,
    required this.roadmapId,
    required this.svc,
    required this.isDark,
    required this.isAr,
    required this.onTaskToggled,
    required this.onAskCoach,
  });
  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
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
    final color = _parseColor(stage.color);
    final isDark = widget.isDark;
    final isAr = widget.isAr;
    final tasks = stage.tasks;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      builder: (_, ctrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222C) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),

              // Sheet header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(stage.icon ?? '📚',
                            style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${isAr ? "المرحلة" : "Stage"} ${stage.order}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: color),
                          ),
                          Text(stage.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1C20))),
                        ]),
                  ),
                  // Progress pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '${stage.completedTaskCount}/${stage.totalTaskCount}',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),

              if (stage.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(stage.description,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.45))),
                ),
              ],

              const SizedBox(height: 12),
              Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),

              // Task list
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          isAr ? 'لا توجد مهام' : 'No tasks',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: tasks.length,
                        itemBuilder: (_, i) => _TaskRow(
                          task: tasks[i],
                          color: color,
                          roadmapId: widget.roadmapId,
                          svc: widget.svc,
                          isDark: isDark,
                          isAr: isAr,
                          onToggled: widget.onTaskToggled,
                          onAskCoach: () => widget.onAskCoach(
                              tasks[i].title, tasks[i].description ?? ''),
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Task Row ───────────────────────────────────────────────────
class _TaskRow extends StatefulWidget {
  final RoadmapTask task;
  final Color color;
  final int roadmapId;
  final RoadmapService svc;
  final bool isDark, isAr;
  final VoidCallback onToggled, onAskCoach;
  const _TaskRow({
    required this.task,
    required this.color,
    required this.roadmapId,
    required this.svc,
    required this.isDark,
    required this.isAr,
    required this.onToggled,
    required this.onAskCoach,
  });
  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final isAr = widget.isAr;
    final color = widget.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? AppColors.emerald.withValues(alpha: 0.05)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isCompleted
              ? AppColors.emerald.withValues(alpha: 0.20)
              : color.withValues(alpha: 0.10),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Checkbox
          GestureDetector(
            onTap: task.isCompleted
                ? null
                : () async {
                    setState(() => _loading = true);
                    await widget.svc.completeTask(widget.roadmapId, task.id);
                    if (mounted) {
                      setState(() => _loading = false);
                      widget.onToggled();
                    }
                  },
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    task.isCompleted ? AppColors.emerald : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted
                      ? AppColors.emerald
                      : color.withValues(alpha: 0.50),
                  width: 2,
                ),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.emerald))
                  : task.isCompleted
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: task.isCompleted
                          ? Colors.grey
                          : (isDark ? Colors.white : const Color(0xFF1A1C20)),
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null)),
              if (task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(task.description!,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.38)
                            : Colors.black.withValues(alpha: 0.38)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ]),

        const SizedBox(height: 10),

        // Action row: estimated hours + resources + Ask Coach
        Row(children: [
          if (task.estimatedHours > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule_rounded,
                    size: 11, color: AppColors.amber),
                const SizedBox(width: 4),
                Text('${task.estimatedHours.toStringAsFixed(0)}h',
                    style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 6),
          ],
          if (task.resources.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showResources(context, task),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.library_books_rounded,
                      size: 11, color: AppColors.cyan),
                  const SizedBox(width: 4),
                  Text('${task.resources.length}',
                      style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          // Ask Coach button
          GestureDetector(
            onTap: widget.onAskCoach,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.psychology_rounded,
                    size: 13, color: AppColors.violet),
                const SizedBox(width: 5),
                Text(isAr ? 'اسأل المدرب' : 'Ask Coach',
                    style: const TextStyle(
                        color: AppColors.violet,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showResources(BuildContext context, RoadmapTask task) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ResourcesSheet(
            task: task, isDark: widget.isDark, isAr: widget.isAr),
      );
}

// ── Resources Sheet (kept from original) ──────────────────────
class _ResourcesSheet extends StatelessWidget {
  final RoadmapTask task;
  final bool isDark, isAr;
  const _ResourcesSheet(
      {required this.task, required this.isDark, required this.isAr});

  IconData _icon(String? t) {
    switch (t) {
      case 'video':
        return Icons.play_circle_rounded;
      case 'course':
        return Icons.school_rounded;
      case 'docs':
        return Icons.description_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Color _color(String? t) {
    switch (t) {
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
    final resources =
        task.resources.where((r) => r['type'] != '_time_log').toList();

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 18),
        Row(children: [
          const Icon(Icons.library_books_rounded,
              color: AppColors.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(task.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Text(
              isAr
                  ? '${resources.length} مصادر'
                  : '${resources.length} resources',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        resources.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(isAr ? 'لا توجد مصادر' : 'No resources yet',
                    style: const TextStyle(color: Colors.grey)))
            : Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: resources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final r = resources[i];
                    final type = r['type'] as String?;
                    final url = r['url']?.toString() ?? '';
                    final hasUrl = url.startsWith('http');
                    final rc = _color(type);

                    return GestureDetector(
                      onTap: hasUrl
                          ? () async {
                              final uri = Uri.tryParse(url);
                              if (uri != null) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: rc.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: rc.withValues(alpha: 0.18))),
                        child: Row(children: [
                          Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: rc.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(11)),
                              child: Icon(_icon(type), color: rc, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(r['title']?.toString() ?? 'Resource',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1C20))),
                                if (hasUrl)
                                  Text(url,
                                      style: TextStyle(color: rc, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                              ])),
                          if (hasUrl)
                            Icon(Icons.open_in_new_rounded,
                                size: 16, color: rc),
                        ]),
                      ),
                    );
                  },
                ),
              ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ANALYTICS SHEET
// ══════════════════════════════════════════════════════════════════
class _AnalyticsSheet extends StatelessWidget {
  final Map<String, dynamic>? analytics;
  final bool isDark, isAr;
  final Roadmap roadmap;
  const _AnalyticsSheet({
    required this.analytics,
    required this.isDark,
    required this.isAr,
    required this.roadmap,
  });

  @override
  Widget build(BuildContext context) {
    final stages = (analytics?['stages'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text(isAr ? 'التحليل' : 'Analytics',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 20),
        // Stats grid
        Row(children: [
          _AStat('${analytics?['completed_tasks'] ?? roadmap.completedTasks}',
              isAr ? 'مكتملة' : 'Done'),
          _AStat('${analytics?['total_tasks'] ?? roadmap.totalTasks}',
              isAr ? 'الكل' : 'Total'),
          _AStat('${analytics?['total_logged_hours'] ?? 0}h',
              isAr ? 'ساعات' : 'Hours'),
          _AStat('${roadmap.overallProgress.toInt()}%',
              isAr ? 'تقدم' : 'Progress'),
        ]),
        if (stages.isNotEmpty) ...[
          const SizedBox(height: 20),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(isAr ? 'تقدم المراحل' : 'Stage Progress',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Colors.grey))),
          const SizedBox(height: 10),
          ...stages.map<Widget>((st) {
            final progress = (st['progress'] as num?)?.toDouble() ?? 0;
            Color sc = AppColors.violet;
            try {
              final hex = st['color']?.toString() ?? '';
              if (hex.isNotEmpty) {
                sc = Color(int.parse(hex.replaceFirst('#', '0xFF')));
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
                                  fontSize: 12, fontWeight: FontWeight.w700))),
                      Text(
                          '${st['completed_tasks'] ?? 0}/${st['total_tasks'] ?? 0}',
                          style: TextStyle(
                              fontSize: 11,
                              color: sc,
                              fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: sc.withValues(alpha: 0.10),
                            color: sc,
                            minHeight: 6)),
                  ]),
            );
          }),
        ],
      ]),
    );
  }
}

class _AStat extends StatelessWidget {
  final String val, lbl;
  const _AStat(this.val, this.lbl);
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
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      );
}
