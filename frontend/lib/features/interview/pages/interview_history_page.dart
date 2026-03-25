// lib/features/interview/pages/interview_history_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/interview_model.dart';
import '../providers/interview_provider.dart';
import '../services/interview_service.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../../shared/widgets/transitions.dart';
import '../../auth/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum _Filter { all, completed, inProgress }

extension _FilterLabel on _Filter {
  String label(bool ar) => switch (this) {
        _Filter.all => ar ? 'الكل' : 'All',
        _Filter.completed => ar ? 'مكتملة' : 'Completed',
        _Filter.inProgress => ar ? 'جارية' : 'In Progress',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
class InterviewHistoryPage extends ConsumerStatefulWidget {
  const InterviewHistoryPage({super.key});
  @override
  ConsumerState<InterviewHistoryPage> createState() =>
      _InterviewHistoryPageState();
}

class _InterviewHistoryPageState extends ConsumerState<InterviewHistoryPage> {
  _Filter _filter = _Filter.all;

  bool get _isAr => Directionality.of(context) == TextDirection.rtl;

  List<Interview> _applyFilter(List<Interview> all) => switch (_filter) {
        _Filter.all => all,
        _Filter.completed => all.where((i) => i.isCompleted).toList(),
        _Filter.inProgress => all.where((i) => !i.isCompleted).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(interviewHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(children: [
        const BackgroundPainter(),
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ─────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.go('/interview'),
                color: isDark ? Colors.white : Colors.black87,
              ),
              title: Text(
                _isAr ? 'سجل التدريب' : 'Practice History',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(interviewHistoryProvider),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ── Content ─────────────────────────────────────────────────
            history.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: InterviewHistorySkeleton(),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorState(
                  error: e.toString(),
                  onRetry: () => ref.invalidate(interviewHistoryProvider),
                ),
              ),
              data: (list) {
                final interviews =
                    list.map((m) => Interview.fromJson(m)).toList();
                final filtered = _applyFilter(interviews);

                if (interviews.isEmpty) {
                  return SliverFillRemaining(
                      child: _EmptyState(isDark: isDark));
                }

                return SliverMainAxisGroup(slivers: [
                  // Stats
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _StatsHeader(
                              interviews: interviews,
                              isDark: isDark,
                              isAr: _isAr))),

                  // Filter chips
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                          child: _FilterBar(
                            current: _filter,
                            isDark: isDark,
                            isAr: _isAr,
                            onChanged: (f) => setState(() => _filter = f),
                          ))),

                  // List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                        child: _EmptyFilterState(isDark: isDark, isAr: _isAr))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _StaggerItem(
                            index: i,
                            child: _PremiumInterviewCard(
                              interview: filtered[i],
                              isDark: isDark,
                              isAr: _isAr,
                              onDelete: () async {
                                await InterviewService()
                                    .deleteInterview(filtered[i].id);
                                if (ctx.mounted) {
                                  ref.invalidate(interviewHistoryProvider);
                                }
                              },
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  final List<Interview> interviews;
  final bool isDark, isAr;
  const _StatsHeader(
      {required this.interviews, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final completed = interviews.where((i) => i.isCompleted).toList();
    final scores =
        completed.where((i) => i.score != null).map((i) => i.score!).toList();
    final avg = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).toInt();
    final best =
        scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b).toInt();
    // Count goal-linked sessions
    final goalLinked = interviews.where((i) => i.goalId != null).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF4C1D95), const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(children: [
        _statCol('${interviews.length}', isAr ? 'الجلسات' : 'Sessions',
            AppColors.violetLt),
        _divider(),
        _statCol(avg > 0 ? '$avg%' : '--', isAr ? 'المتوسط' : 'Avg Score',
            AppColors.cyan),
        _divider(),
        _statCol(best > 0 ? '$best%' : '--', isAr ? 'الأفضل' : 'Best',
            AppColors.emerald),
        // ── Goal-linked count ──────────────────────────────────────────
        if (goalLinked > 0) ...[
          _divider(),
          _statCol('$goalLinked', '🎯', AppColors.amber),
        ],
      ]),
    );
  }

  Widget _statCol(String v, String l, Color c) => Expanded(
          child: Column(children: [
        Text(v,
            style:
                TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 4),
        Text(l.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]));

  Widget _divider() => Container(width: 1, height: 32, color: Colors.white12);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final _Filter current;
  final bool isDark, isAr;
  final ValueChanged<_Filter> onChanged;
  const _FilterBar(
      {required this.current,
      required this.isDark,
      required this.isAr,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _Filter.values.map((f) {
          final active = f == current;
          final color = switch (f) {
            _Filter.all => AppColors.violet,
            _Filter.completed => AppColors.emerald,
            _Filter.inProgress => AppColors.amber,
          };
          return TapScale(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? color : Colors.transparent, width: 1.5),
              ),
              child: Text(f.label(isAr),
                  style: TextStyle(
                    color: active
                        ? color
                        : (isDark ? Colors.white54 : Colors.black45),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGER WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
        ),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM INTERVIEW CARD — with goal badge
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumInterviewCard extends StatefulWidget {
  final Interview interview;
  final Future<void> Function() onDelete;
  final bool isDark, isAr;

  const _PremiumInterviewCard({
    required this.interview,
    required this.onDelete,
    required this.isDark,
    required this.isAr,
  });

  @override
  State<_PremiumInterviewCard> createState() => _PremiumInterviewCardState();
}

class _PremiumInterviewCardState extends State<_PremiumInterviewCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final interview = widget.interview;
    final isDark = widget.isDark;
    final isAr = widget.isAr;
    final score = interview.score;

    final color = interview.isCompleted
        ? (score != null
            ? (score >= 70
                ? AppColors.emerald
                : (score >= 40 ? AppColors.amber : AppColors.rose))
            : Colors.grey)
        : AppColors.violet;

    final hasFeedback = interview.feedback != null &&
        (interview.feedback!['overall_feedback'] as String? ?? '').isNotEmpty;

    return TapScale(
      onTap: hasFeedback ? _toggle : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          isDark: isDark,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top row ─────────────────────────────────────────────
            Row(children: [
              // Score circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(
                  child: score != null
                      ? Text(score.toStringAsFixed(0),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: color,
                              fontSize: 18))
                      : Icon(Icons.psychology_rounded, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 14),

              // Role + badges
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Role row with goal badge ───────────────────────
                      Row(children: [
                        Expanded(
                          child: Text(interview.jobRole,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color:
                                      isDark ? Colors.white : Colors.black87),
                              overflow: TextOverflow.ellipsis),
                        ),
                        // 🎯 Goal badge
                        if (interview.goalId != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.violet.withValues(alpha: 0.3)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.flag_rounded,
                                  color: AppColors.violet, size: 10),
                              const SizedBox(width: 3),
                              Text(isAr ? 'هدف' : 'Goal',
                                  style: const TextStyle(
                                      color: AppColors.violet,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900)),
                            ]),
                          ),
                      ]),

                      const SizedBox(height: 6),
                      Row(children: [
                        _miniBadge(interview.difficulty.toUpperCase(),
                            AppColors.amber, isDark),
                        const SizedBox(width: 6),
                        _miniBadge(
                            interview.interviewType, AppColors.cyan, isDark),
                        const SizedBox(width: 6),
                        _statusBadge(interview.isCompleted, isAr),
                      ]),
                    ]),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.rose, size: 22),
                onPressed: () => _confirmDelete(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),

            // ── Score bar ────────────────────────────────────────────
            if (score != null && interview.isCompleted) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )),
                const SizedBox(width: 8),
                Text('${score.toInt()}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ]),
            ],

            // ── Meta row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 11, color: Colors.grey),
                const SizedBox(width: 5),
                Text(_fmtDate(interview.createdAt),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                if (interview.durationMinutes != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.timer_outlined,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${interview.durationMinutes} ${isAr ? 'دقيقة' : 'min'}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600)),
                ],
                const Spacer(),
                if (hasFeedback)
                  Row(children: [
                    Text(isAr ? 'التغذية الراجعة' : 'Feedback',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.violet,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: AppColors.violet),
                    ),
                  ]),
              ]),
            ),

            // ── Expandable feedback panel ─────────────────────────────
            if (hasFeedback)
              SizeTransition(
                sizeFactor: _expandAnim,
                child: FadeTransition(
                  opacity: _expandAnim,
                  child: _FeedbackPanel(
                    feedback: interview.feedback!,
                    isDark: isDark,
                    isAr: isAr,
                    scoreColor: color,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final isAr = widget.isAr;
    final isDark = widget.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isAr ? 'حذف الجلسة؟' : 'Delete Session?',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(isAr
            ? 'سيؤدي هذا إلى حذف المقابلة وتغذيتها الراجعة نهائياً.'
            : 'This will permanently remove this interview and its AI feedback.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onDelete();
            },
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );

  Widget _statusBadge(bool completed, bool isAr) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.emerald.withValues(alpha: 0.1)
              : AppColors.violet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
            completed
                ? (isAr ? 'مكتملة' : 'DONE')
                : (isAr ? 'جارية' : 'PAUSED'),
            style: TextStyle(
                color: completed ? AppColors.emerald : AppColors.violet,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
      );

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// FEEDBACK PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackPanel extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final bool isDark, isAr;
  final Color scoreColor;
  const _FeedbackPanel(
      {required this.feedback,
      required this.isDark,
      required this.isAr,
      required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    final overall = feedback['overall_feedback'] as String? ?? '';
    final strengths = (feedback['strengths'] as List?)?.cast<String>() ?? [];
    final improvements =
        (feedback['improvements'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (overall.isNotEmpty) ...[
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: scoreColor),
            const SizedBox(width: 6),
            Text(isAr ? 'التقييم العام' : 'AI Feedback',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scoreColor)),
          ]),
          const SizedBox(height: 8),
          Text(overall,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark ? Colors.white70 : Colors.black54)),
        ],
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FeedbackSection(
              icon: Icons.check_circle_rounded,
              color: AppColors.emerald,
              title: isAr ? 'نقاط القوة' : 'Strengths',
              items: strengths,
              isDark: isDark),
        ],
        if (improvements.isNotEmpty) ...[
          const SizedBox(height: 10),
          _FeedbackSection(
              icon: Icons.lightbulb_rounded,
              color: AppColors.amber,
              title: isAr ? 'مجالات التحسين' : 'To Improve',
              items: improvements,
              isDark: isDark),
        ],
      ]),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;
  final bool isDark;
  const _FeedbackSection(
      {required this.icon,
      required this.color,
      required this.title,
      required this.items,
      required this.isDark});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(title,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 6),
        ...items.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: isDark ? Colors.white60 : Colors.black54))),
              ]),
            )),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATES & ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});
  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_edu_rounded,
          size: 64, color: isDark ? Colors.white12 : Colors.black12),
      const SizedBox(height: 16),
      Text(isAr ? 'لا توجد جلسات بعد' : 'No Sessions Yet',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
      const SizedBox(height: 8),
      Text(
          isAr
              ? 'ستظهر مقابلاتك المكتملة هنا'
              : 'Your completed interviews will appear here.',
          style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 32),
      TapScale(
        onTap: () => context.go('/interview'),
        child: ElevatedButton(
          onPressed: () => context.go('/interview'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          child: Text(isAr ? 'ابدأ أول مقابلة' : 'Start First Interview',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ]));
  }
}

class _EmptyFilterState extends StatelessWidget {
  final bool isDark, isAr;
  const _EmptyFilterState({required this.isDark, required this.isAr});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.filter_list_off_rounded,
            size: 48, color: isDark ? Colors.white12 : Colors.black12),
        const SizedBox(height: 12),
        Text(isAr ? 'لا توجد نتائج لهذا الفلتر' : 'No results for this filter',
            style: const TextStyle(color: Colors.grey)),
      ]));
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.rose),
        const SizedBox(height: 16),
        Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
        TextButton(
            onPressed: onRetry,
            child:
                const Text('Retry', style: TextStyle(color: AppColors.violet))),
      ]));
}
