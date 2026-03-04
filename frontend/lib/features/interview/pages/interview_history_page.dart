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
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard

class InterviewHistoryPage extends ConsumerWidget {
  const InterviewHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(interviewHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          const BackgroundPainter(),
          CustomScrollView(
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
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/interview'),
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text('Practice History',
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
              history.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.violet)),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: _ErrorState(
                      error: e.toString(),
                      onRetry: () => ref.invalidate(interviewHistoryProvider)),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                        child: _EmptyState(isDark: isDark));
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          // FutureProvider returns List<Map<String,dynamic>>
                          final interview = Interview.fromJson(list[i]);
                          return _PremiumInterviewCard(
                            interview: interview,
                            isDark: isDark,
                            onDelete: () async {
                              // FutureProvider has no .notifier —
                              // call service directly then invalidate
                              await InterviewService()
                                  .deleteInterview(interview.id);
                              ref.invalidate(interviewHistoryProvider);
                            },
                          );
                        },
                        childCount: list.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM INTERVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumInterviewCard extends StatelessWidget {
  final Interview interview;
  final Future<void> Function() onDelete;
  final bool isDark;

  const _PremiumInterviewCard(
      {required this.interview, required this.onDelete, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final score = interview.score;
    final color = interview.isCompleted
        ? (score != null
            ? (score >= 70
                ? AppColors.emerald
                : (score >= 40 ? AppColors.amber : AppColors.rose))
            : Colors.grey)
        : AppColors.violet;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        isDark: isDark,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: score != null
                        ? Text(score.toStringAsFixed(0),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: color,
                                fontSize: 18))
                        : Icon(Icons.psychology_rounded,
                            color: color, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(interview.jobRole,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _miniBadge(interview.difficulty.toUpperCase(),
                            isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 8),
                        _miniBadge(interview.interviewType, AppColors.cyan),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.rose, size: 22),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(_fmtDate(interview.createdAt),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ]),
                if (interview.durationMinutes != null)
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${interview.durationMinutes} min',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold)),
                  ]),
                _statusBadge(interview.isCompleted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Session?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'This will permanently remove this interview and its AI feedback.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              await onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) => Text(text,
      style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5));

  Widget _statusBadge(bool completed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.emerald.withValues(alpha: 0.1)
              : AppColors.violet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(completed ? 'COMPLETED' : 'PAUSED',
            style: TextStyle(
                color: completed ? AppColors.emerald : AppColors.violet,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
      );

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
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
              child: const Text('Try Again',
                  style: TextStyle(color: AppColors.violet))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_edu_rounded,
              size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 16),
          const Text('No Sessions Yet',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Your completed interviews will appear here.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/interview'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            child: const Text('Start First Interview',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}
