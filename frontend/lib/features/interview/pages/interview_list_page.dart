// lib/features/interview/pages/interview_list_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/interview_provider.dart';
import '../models/interview_model.dart';
import '../services/interview_service.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/skeleton_widgets.dart';
import '../../../shared/widgets/transitions.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard, PrimaryButton

class InterviewListPage extends ConsumerStatefulWidget {
  const InterviewListPage({super.key});
  @override
  ConsumerState<InterviewListPage> createState() => _InterviewListPageState();
}

class _InterviewListPageState extends ConsumerState<InterviewListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(interviewHistoryProvider));
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(interviewHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          const BackgroundPainter(),
          history.when(
            loading: () => _buildSkeleton(s),
            error: (e, _) => _buildError(e.toString(), s),
            data: (list) {
              final interviews =
                  list.map((item) => Interview.fromJson(item)).toList();
              return _buildBody(interviews, isDark, s);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(AppStrings s) => CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          title: Text(s.interviewTitle,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          actions: const [ThemeToggleButton(), SizedBox(width: 8)],
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 20),
            child: InterviewHistorySkeleton(),
          ),
        ),
      ]);

  Widget _buildBody(List<Interview> list, bool isDark, AppStrings s) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
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
          title: Text(s.interviewTitle,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5)),
          actions: [
            const ThemeToggleButton(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(interviewHistoryProvider),
            ),
            const SizedBox(width: 8),
          ],
        ),
        if (list.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _PremiumStatsBar(interviews: list, isDark: isDark, s: s),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: TapScale(
              onTap: () => context.push('/interview/setup'),
              child: _ModernNewInterviewCard(isDark: isDark, s: s),
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(child: _EmptyState(isDark: isDark, s: s))
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(s.interviewHistory2,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _StaggeredItem(
                  index: i,
                  child: TapScale(
                    onTap: () => _handleTap(list[i]),
                    child: _SwipeableCard(
                      interview: list[i],
                      isDark: isDark,
                      s: s,
                      onTap: () => _handleTap(list[i]),
                      onDelete: () =>
                          _confirmDelete(list[i].id, list[i].jobRole, s),
                    ),
                  ),
                ),
                childCount: list.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleTap(Interview interview) {
    if (interview.isCompleted) {
      _showResultSheet(interview);
    } else {
      context.push('/interview/chat');
    }
  }

  void _showResultSheet(Interview interview) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(interview: interview, isDark: isDark),
    );
  }

  Future<void> _confirmDelete(int id, String role, AppStrings s) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(s.interviewDeleteTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('${s.interviewDeleteTitle} "$role"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await InterviewService().deleteInterview(id);
      if (mounted) ref.invalidate(interviewHistoryProvider);
    }
  }

  Widget _buildError(String error, AppStrings s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.rose),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            TextButton(
                onPressed: () => ref.invalidate(interviewHistoryProvider),
                child: Text(s.retry)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGER
// ─────────────────────────────────────────────────────────────────────────────
class _StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
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
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumStatsBar extends StatelessWidget {
  final List<Interview> interviews;
  final bool isDark;
  final AppStrings s;
  const _PremiumStatsBar(
      {required this.interviews, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final completed = interviews.where((i) => i.isCompleted).toList();
    final scores =
        completed.where((i) => i.score != null).map((i) => i.score!).toList();
    final avgScore = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).toInt();

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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        _statItem(
            '${interviews.length}', s.interviewSessions, AppColors.violetLt),
        _divider(),
        _statItem(
            '${completed.length}', s.interviewCompleted, AppColors.emerald),
        _divider(),
        _statItem('$avgScore%', s.interviewAvgScore, AppColors.amber),
      ]),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
          child: Column(children: [
        Text(v,
            style:
                TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 4),
        Text(l.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]));

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white10);
}

class _ModernNewInterviewCard extends StatelessWidget {
  final bool isDark;
  final AppStrings s;
  const _ModernNewInterviewCard({required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/interview/setup'),
      child: GlassCard(
        isDark: isDark,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.violet, AppColors.violetDk]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.interviewStartPractice,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(s.interviewAiPowered,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.violet),
        ]),
      ),
    );
  }
}

class _SwipeableCard extends StatelessWidget {
  final Interview interview;
  final bool isDark;
  final AppStrings s;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SwipeableCard(
      {required this.interview,
      required this.isDark,
      required this.s,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('int_${interview.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: AppColors.rose, borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            isDark: isDark,
            child: Row(children: [
              _ScoreIndicator(score: interview.score, isDark: isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(interview.jobRole,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _miniBadge(interview.difficulty.toUpperCase(),
                            AppColors.amber),
                        const SizedBox(width: 8),
                        _miniBadge(interview.interviewType, AppColors.cyan),
                        const SizedBox(width: 8),
                        _statusBadge(interview.isCompleted, s),
                      ]),
                    ]),
              ),
              Icon(
                  interview.isCompleted
                      ? Icons.chevron_right_rounded
                      : Icons.play_circle_filled_rounded,
                  color:
                      interview.isCompleted ? Colors.grey : AppColors.violet),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );

  Widget _statusBadge(bool completed, AppStrings s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.emerald.withValues(alpha: 0.1)
              : AppColors.violet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(completed ? s.interviewCompleted : s.interviewPaused,
            style: TextStyle(
                color: completed ? AppColors.emerald : AppColors.violet,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
      );
}

class _ScoreIndicator extends StatelessWidget {
  final double? score;
  final bool isDark;
  const _ScoreIndicator({this.score, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = score == null
        ? AppColors.violet
        : (score! >= 70 ? AppColors.emerald : AppColors.amber);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2)),
      child: Center(
        child: score == null
            ? Icon(Icons.pending_actions_rounded, color: color, size: 20)
            : Text(score!.toInt().toString(),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final Interview interview;
  final bool isDark;
  const _ResultSheet({required this.interview, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
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
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(interview.jobRole,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 16),
            if (interview.feedback != null)
              Text(
                  interview.feedback!['overall_feedback'] ?? 'No feedback yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                    label: s.done,
                    isLoading: false,
                    onTap: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final AppStrings s;
  const _EmptyState({required this.isDark, required this.s});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.mic_none_rounded,
              size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 16),
          Text(s.interviewNoHistory,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(s.interviewHistorySub,
              style: const TextStyle(color: Colors.grey)),
        ]),
      );
}
