// lib/features/interview/pages/interview_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../providers/interview_provider.dart';
import '../services/interview_service.dart';

// ══════════════════════════════════════════════════════════════════
// PUBLIC MODEL — used by list page + replay page
// ══════════════════════════════════════════════════════════════════
class InterviewSummary {
  final int id;
  final String jobRole, difficulty, type, status, language;
  final double? score;
  final String grade, recommendation;
  final int messageCount;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMinutes;

  const InterviewSummary({
    required this.id,
    required this.jobRole,
    required this.difficulty,
    required this.type,
    required this.status,
    required this.language,
    this.score,
    required this.grade,
    required this.recommendation,
    required this.messageCount,
    required this.startedAt,
    this.completedAt,
    this.durationMinutes,
  });

  bool get isCompleted => status == 'completed';

  factory InterviewSummary.from(Map<String, dynamic> m) => InterviewSummary(
        id: m['id'] as int,
        jobRole: m['job_role']?.toString() ?? '—',
        difficulty: m['difficulty']?.toString() ?? 'medium',
        type: m['interview_type']?.toString() ?? 'mixed',
        status: m['status']?.toString() ?? 'in_progress',
        language: m['language']?.toString() ?? 'en',
        score: (m['score'] as num?)?.toDouble(),
        grade: m['grade']?.toString() ?? '',
        recommendation: m['recommendation']?.toString() ?? '',
        messageCount: (m['message_count'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(m['started_at']?.toString() ?? '') ??
            DateTime.now(),
        completedAt: m['completed_at'] != null
            ? DateTime.tryParse(m['completed_at'].toString())
            : null,
        durationMinutes: (m['duration_minutes'] as num?)?.toInt(),
      );

  Color scoreColor() {
    if (score == null || score! <= 0) return Colors.grey;
    if (score! >= 70) return AppColors.emerald;
    if (score! >= 40) return AppColors.amber;
    return AppColors.rose;
  }

  String fmtDate() {
    final d = startedAt.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Provider for single interview detail ─────────────────────────
final interviewDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return InterviewService().getInterviewDetail(id);
});

// ══════════════════════════════════════════════════════════════════
// HISTORY PAGE
// ══════════════════════════════════════════════════════════════════
class InterviewHistoryPage extends ConsumerStatefulWidget {
  const InterviewHistoryPage({super.key});
  @override
  ConsumerState<InterviewHistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<InterviewHistoryPage> {
  String _filter = 'all';

  void _openReplay(InterviewSummary s) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim, child: InterviewReplayPage(interview: s)),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final history = ref.watch(interviewHistoryProvider);
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Column(children: [
        // ── Header (manual top padding = no SafeArea needed) ─────
        SizedBox(height: MediaQuery.of(context).padding.top),
        _HistoryHeader(
            isDark: isDark,
            isAr: isAr,
            onBack: () => context.go('/interview'),
            onRefresh: () => ref.invalidate(interviewHistoryProvider)),

        // ── Content ──────────────────────────────────────────────
        Expanded(
            child: history.when(
          loading: () => _Shimmer(isDark: isDark),
          error: (_, __) => _ErrView(
              isAr: isAr,
              onRetry: () => ref.invalidate(interviewHistoryProvider)),
          data: (raw) {
            if (raw.isEmpty) return _EmptyView(isDark: isDark, isAr: isAr);

            final all = raw.map(InterviewSummary.from).toList();
            final filtered = _filter == 'all'
                ? all
                : _filter == 'completed'
                    ? all.where((i) => i.isCompleted).toList()
                    : all.where((i) => !i.isCompleted).toList();

            final scores = all
                .where((i) => i.isCompleted && i.score != null && i.score! > 0)
                .map((i) => i.score!);
            final avg = scores.isEmpty
                ? 0
                : (scores.reduce((a, b) => a + b) / scores.length).toInt();
            final best = scores.isEmpty
                ? 0
                : scores.reduce((a, b) => a > b ? a : b).toInt();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Stats card
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _StatsCard(
                      total: all.length,
                      avg: avg,
                      best: best,
                      isDark: isDark,
                      isAr: isAr),
                )),

                // Filter pills
                SliverToBoxAdapter(
                    child: _FilterPills(
                        current: _filter,
                        isDark: isDark,
                        isAr: isAr,
                        onChange: (f) {
                          HapticFeedback.lightImpact();
                          setState(() => _filter = f);
                        })),

                // No results
                if (filtered.isEmpty)
                  SliverFillRemaining(
                      child: Center(
                          child: Text(isAr ? 'لا توجد نتائج' : 'No results',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 15)))),

                // Cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _HistoryCard(
                      interview: filtered[i],
                      isDark: isDark,
                      isAr: isAr,
                      index: i,
                      onTap: () => _openReplay(filtered[i]),
                      onDelete: () async {
                        HapticFeedback.heavyImpact();
                        await InterviewService()
                            .deleteInterview(filtered[i].id);
                        if (ctx.mounted) {
                          ref.invalidate(interviewHistoryProvider);
                        }
                      },
                    ),
                    childCount: filtered.length,
                  )),
                ),
              ],
            );
          },
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HEADER — matches list/setup page style
// ══════════════════════════════════════════════════════════════════
class _HistoryHeader extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onBack, onRefresh;
  const _HistoryHeader(
      {required this.isDark,
      required this.isAr,
      required this.onBack,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
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
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    isAr
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : Colors.black.withValues(alpha: 0.70),
                    size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(isAr ? 'سجل الأداء' : 'Performance History',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF1A1C20)))),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRefresh();
            },
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.refresh_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : Colors.black.withValues(alpha: 0.60),
                    size: 20)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// STATS CARD — same gradient as list page
// ══════════════════════════════════════════════════════════════════
class _StatsCard extends StatelessWidget {
  final int total, avg, best;
  final bool isDark, isAr;
  const _StatsCard(
      {required this.total,
      required this.avg,
      required this.best,
      required this.isDark,
      required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF5B2BE2), Color(0xFF7B3FE4), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7B3FE4).withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _SC(isAr ? 'الجلسات' : 'SESSIONS', '$total'),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.20)),
          _SC(isAr ? 'المتوسط' : 'AVG', avg > 0 ? '$avg%' : '—'),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.20)),
          _SC(isAr ? 'الأفضل' : 'BEST', best > 0 ? '$best%' : '—'),
        ]),
      );
}

class _SC extends StatelessWidget {
  final String label, val;
  const _SC(this.label, this.val);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// FILTER PILLS — same style as list page
// ══════════════════════════════════════════════════════════════════
class _FilterPills extends StatelessWidget {
  final String current;
  final bool isDark, isAr;
  final ValueChanged<String> onChange;
  const _FilterPills(
      {required this.current,
      required this.isDark,
      required this.isAr,
      required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('all', isAr ? 'الكل' : 'All'),
      ('completed', isAr ? 'مكتملة' : 'Done'),
      ('in_progress', isAr ? 'جارية' : 'Active'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
          children: items.map((f) {
        final active = f.$1 == current;
        return GestureDetector(
          onTap: () => onChange(f.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? Colors.white : AppColors.violet)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white),
              borderRadius: BorderRadius.circular(100),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Text(f.$2,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.40)))),
          ),
        );
      }).toList()),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HISTORY CARD — same style as list page cards
// ══════════════════════════════════════════════════════════════════
class _HistoryCard extends StatelessWidget {
  final InterviewSummary interview;
  final bool isDark, isAr;
  final int index;
  final VoidCallback onTap, onDelete;
  const _HistoryCard(
      {required this.interview,
      required this.isDark,
      required this.isAr,
      required this.index,
      required this.onTap,
      required this.onDelete});

  String _diffLabel(bool ar) => switch (interview.difficulty) {
        'easy' => ar ? 'سهل' : 'Easy',
        'medium' => ar ? 'متوسط' : 'Medium',
        'hard' => ar ? 'صعب' : 'Hard',
        _ => interview.difficulty,
      };

  String _recLabel(bool ar) {
    final r = interview.recommendation.toLowerCase();
    if (!ar) return interview.recommendation;
    if (r.contains('hire')) return 'جاهز للتوظيف ✅';
    if (r.contains('strong')) return 'يستحق التقديم';
    if (r.contains('consider')) return 'يحتاج تطوير';
    return interview.recommendation;
  }

  @override
  Widget build(BuildContext context) {
    final color = interview.scoreColor();
    final hasScore = interview.isCompleted &&
        interview.score != null &&
        interview.score! > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)), child: child)),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            // Score ring — static, color-coded
            SizedBox(
                width: 50,
                height: 50,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: hasScore
                        ? (interview.score! / 100).clamp(0.0, 1.0)
                        : 0.0,
                    strokeWidth: 4,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.10),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                      child: hasScore
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('${interview.score!.toInt()}',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900)),
                              Text('%',
                                  style: TextStyle(
                                      color: color.withValues(alpha: 0.55),
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700)),
                            ])
                          : Text('—',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : Colors.black.withValues(alpha: 0.30),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700))),
                ])),
            const SizedBox(width: 14),

            // Info
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(interview.jobRole,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    _Chip(_diffLabel(isAr), AppColors.violet),
                    const SizedBox(width: 6),
                    _Chip(interview.fmtDate(), Colors.grey),
                    if (interview.messageCount > 0) ...[
                      const SizedBox(width: 6),
                      _Chip('${interview.messageCount ~/ 2} Q', AppColors.cyan),
                    ],
                  ]),
                  if (interview.isCompleted &&
                      interview.recommendation.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(_recLabel(isAr),
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ])),

            const SizedBox(width: 8),

            // Right side
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                  isAr
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.violet,
                  size: 16),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.rose, size: 15)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

// ══════════════════════════════════════════════════════════════════
// REPLAY PAGE — public, called from list page + history page
// ══════════════════════════════════════════════════════════════════
class InterviewReplayPage extends ConsumerWidget {
  final InterviewSummary interview;
  const InterviewReplayPage({super.key, required this.interview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final detail = ref.watch(interviewDetailProvider(interview.id));
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        SizedBox(height: MediaQuery.of(context).padding.top),
        // Header
        _ReplayHeader(
            interview: interview,
            isDark: isDark,
            isAr: isAr,
            onBack: () => Navigator.pop(context)),

        // Content
        Expanded(
            child: detail.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.violet)),
          error: (_, __) => _fallback(isDark, isAr),
          data: (data) {
            final messages = (data['messages'] as List? ?? [])
                .cast<Map<String, dynamic>>()
                .where((m) => (m['content']?.toString() ?? '').isNotEmpty)
                .toList();
            final feedback = data['feedback'] as Map<String, dynamic>?;
            if (messages.isEmpty && feedback == null) {
              return _fallback(isDark, isAr);
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Score summary card
                if (interview.isCompleted)
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _ScoreSummary(
                        interview: interview,
                        feedback: feedback,
                        isDark: isDark,
                        isAr: isAr),
                  )),

                // Conversation label
                if (messages.isNotEmpty)
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                        (isAr ? 'سجل المحادثة' : 'CONVERSATION').toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.35))),
                  )),

                // Messages
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                    (_, i) => _MsgBubble(
                        role: messages[i]['role'] ?? '',
                        content: messages[i]['content'] ?? '',
                        isDark: isDark),
                    childCount: messages.length,
                  )),
                ),

                // Feedback
                if (feedback != null && interview.isCompleted)
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
                    child: _FeedbackDetail(
                        feedback: feedback, isDark: isDark, isAr: isAr),
                  )),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        )),
      ]),
    );
  }

  Widget _fallback(bool isDark, bool isAr) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_rounded,
            size: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08)),
        const SizedBox(height: 12),
        Text(isAr ? 'لا توجد تفاصيل' : 'No details available',
            style: const TextStyle(color: Colors.grey)),
      ]));
}

// ── Replay header ─────────────────────────────────────────────────
class _ReplayHeader extends StatelessWidget {
  final InterviewSummary interview;
  final bool isDark, isAr;
  final VoidCallback onBack;
  const _ReplayHeader(
      {required this.interview,
      required this.isDark,
      required this.isAr,
      required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
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
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    isAr
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : Colors.black.withValues(alpha: 0.70),
                    size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(interview.jobRole,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: isDark ? Colors.white : const Color(0xFF1A1C20)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _HChip(interview.difficulty, AppColors.violet),
                  const SizedBox(width: 6),
                  _HChip(interview.fmtDate(), Colors.grey),
                  if (interview.isCompleted &&
                      interview.score != null &&
                      interview.score! > 0) ...[
                    const SizedBox(width: 6),
                    _HChip(
                        '${interview.score!.toInt()}%', interview.scoreColor()),
                  ],
                ]),
              ])),
        ]),
      );
}

class _HChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

// ── Score summary ─────────────────────────────────────────────────
class _ScoreSummary extends StatelessWidget {
  final InterviewSummary interview;
  final Map<String, dynamic>? feedback;
  final bool isDark, isAr;
  const _ScoreSummary(
      {required this.interview,
      this.feedback,
      required this.isDark,
      required this.isAr});

  @override
  Widget build(BuildContext context) {
    final color = interview.scoreColor();
    final score = interview.score ?? 0;
    final overall = feedback?['overall_feedback']?.toString() ??
        feedback?['summary']?.toString() ??
        '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Row(children: [
          // Big score ring
          SizedBox(
              width: 72,
              height: 72,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(
                    value: (score / 100).clamp(0.0, 1.0),
                    strokeWidth: 7,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.10),
                    strokeCap: StrokeCap.round),
                Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${score.toInt()}',
                      style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  if (interview.grade.isNotEmpty)
                    Text(interview.grade,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                ])),
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(interview.jobRole,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A1C20)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (interview.recommendation.isNotEmpty)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(interview.recommendation,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))),
                const SizedBox(height: 4),
                Text(interview.fmtDate(),
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ])),
        ]),
        if (overall.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome_rounded, color: color, size: 15),
            const SizedBox(width: 8),
            Expanded(
                child: Text(overall,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.60)
                            : Colors.black.withValues(alpha: 0.55)))),
          ]),
        ],
      ]),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────
class _MsgBubble extends StatelessWidget {
  final String role, content;
  final bool isDark;
  const _MsgBubble(
      {required this.role, required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 2, right: 6),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.violet, Color(0xFF6D28D9)]),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 14)),
            ],
            Flexible(
                child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.violet
                    : (isDark ? const Color(0xFF1E222C) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text(content,
                  style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.87)
                              : Colors.black87),
                      fontSize: 14,
                      height: 1.45)),
            )),
            if (isUser) ...[
              Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 2, left: 6),
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.violet, size: 14)),
            ],
          ]),
    );
  }
}

// ── Feedback detail ───────────────────────────────────────────────
class _FeedbackDetail extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final bool isDark, isAr;
  const _FeedbackDetail(
      {required this.feedback, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final strengths = ((feedback['strengths'] as List?) ??
            (feedback['top_strengths'] as List?) ??
            [])
        .cast<String>();
    final improvements = ((feedback['areas_for_improvement'] as List?) ??
            (feedback['areas_to_improve'] as List?) ??
            [])
        .cast<String>();
    final actions = (feedback['action_items'] as List? ?? []).cast<String>();
    if (strengths.isEmpty && improvements.isEmpty && actions.isEmpty) {
      return const SizedBox();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text((isAr ? 'التغذية الراجعة' : 'FEEDBACK').toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35)))),
      if (strengths.isNotEmpty)
        _FbBlock(
            icon: Icons.check_circle_rounded,
            color: AppColors.emerald,
            title: isAr ? 'نقاط القوة' : 'Strengths',
            items: strengths,
            isDark: isDark),
      if (improvements.isNotEmpty) ...[
        const SizedBox(height: 10),
        _FbBlock(
            icon: Icons.trending_up_rounded,
            color: AppColors.amber,
            title: isAr ? 'مجالات التحسين' : 'To Improve',
            items: improvements,
            isDark: isDark),
      ],
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 10),
        _FbBlock(
            icon: Icons.checklist_rounded,
            color: AppColors.violet,
            title: isAr ? 'خطوات عملية' : 'Action Items',
            items: actions,
            isDark: isDark),
      ],
    ]);
  }
}

class _FbBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;
  final bool isDark;
  const _FbBlock(
      {required this.icon,
      required this.color,
      required this.title,
      required this.items,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.60),
                                  shape: BoxShape.circle))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.60)
                                      : Colors.black.withValues(alpha: 0.55)))),
                    ]),
              )),
        ]),
      );
}

// ── Empty / Error / Shimmer ───────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool isDark, isAr;
  const _EmptyView({required this.isDark, required this.isAr});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded,
                color: AppColors.violet, size: 40)),
        const SizedBox(height: 18),
        Text(isAr ? 'لا توجد مقابلات بعد' : 'No Interviews Yet',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF1A1C20))),
        const SizedBox(height: 8),
        Text(
            isAr ? 'ابدأ أول مقابلة لك الآن' : 'Start your first interview now',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go('/interview/setup');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ]),
            child: Text(isAr ? 'ابدأ الآن' : 'Start Now',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]));
}

class _ErrView extends StatelessWidget {
  final bool isAr;
  final VoidCallback onRetry;
  const _ErrView({required this.isAr, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.rose),
        const SizedBox(height: 12),
        Text(isAr ? 'فشل التحميل' : 'Failed to load',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 14),
        GestureDetector(
            onTap: onRetry,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(14)),
                child: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)))),
      ]));
}

class _Shimmer extends StatefulWidget {
  final bool isDark;
  const _Shimmer({required this.isDark});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final v = 0.04 + 0.07 * _a.value;
        final hi = widget.isDark
            ? Colors.white.withValues(alpha: v)
            : Colors.black.withValues(alpha: v);
        final lo = widget.isDark
            ? Colors.white.withValues(alpha: v * 0.45)
            : Colors.black.withValues(alpha: v * 0.45);
        final card = widget.isDark ? const Color(0xFF1E222C) : Colors.white;

        Widget b(double w, double h, {double r = 8, Color? c}) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                color: c ?? lo, borderRadius: BorderRadius.circular(r)));

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Stats card
            Container(
                height: 88,
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(26))),
            const SizedBox(height: 16),
            // Filter pills
            Row(children: [
              b(48, 38, r: 100, c: hi),
              const SizedBox(width: 10),
              b(60, 38, r: 100),
              const SizedBox(width: 10),
              b(56, 38, r: 100)
            ]),
            const SizedBox(height: 6),
            // Cards
            ...List.generate(
                5,
                (i) => Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      child: Row(children: [
                        b(50, 50, r: 25, c: hi),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              b(i.isEven ? 130.0 : 100.0, 14, r: 6, c: hi),
                              const SizedBox(height: 8),
                              Row(children: [
                                b(40, 9, r: 5),
                                const SizedBox(width: 6),
                                b(36, 9, r: 5)
                              ]),
                            ])),
                        const SizedBox(width: 8),
                        Column(children: [
                          b(14, 14, r: 7),
                          const SizedBox(height: 8),
                          b(30, 30, r: 15)
                        ]),
                      ]),
                    )),
          ]),
        );
      });
}
