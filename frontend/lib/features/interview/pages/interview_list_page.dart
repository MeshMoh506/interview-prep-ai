// lib/features/interview/pages/interview_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'interview_history_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/interview_provider.dart';
import '../models/interview_model.dart';
import '../services/interview_service.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../auth/providers/auth_provider.dart';

enum _Filter { all, completed, inProgress }

// ── Localized filter labels ───────────────────────────────────────
extension _FL on _Filter {
  String label(bool ar) => switch (this) {
        _Filter.all => ar ? 'الكل' : 'All',
        _Filter.completed => ar ? 'مكتملة' : 'Done',
        _Filter.inProgress => ar ? 'جارية' : 'Active',
      };
}

class InterviewListPage extends ConsumerStatefulWidget {
  const InterviewListPage({super.key});
  @override
  ConsumerState<InterviewListPage> createState() => _InterviewListPageState();
}

class _InterviewListPageState extends ConsumerState<InterviewListPage> {
  _Filter _filter = _Filter.all;
  bool _searching = false;
  String _query = '';
  late final _searchCtrl = TextEditingController();
  late final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(interviewHistoryProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Interview> _filterList(List<Interview> all) {
    var list = all;
    if (_filter == _Filter.completed) {
      list = list.where((i) => i.isCompleted).toList();
    }
    if (_filter == _Filter.inProgress) {
      list = list.where((i) => !i.isCompleted).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((i) =>
              i.jobRole.toLowerCase().contains(q) ||
              i.difficulty.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _openSearch() {
    setState(() => _searching = true);
    Future.delayed(const Duration(milliseconds: 80), _searchFocus.requestFocus);
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
  }

  void _openReplay(Interview iv) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: InterviewReplayPage(
              interview: InterviewSummary.from({
            'id': iv.id,
            'job_role': iv.jobRole,
            'difficulty': iv.difficulty,
            'interview_type': iv.interviewType,
            'status': iv.isCompleted ? 'completed' : 'in_progress',
            'language': 'en',
            'score': iv.score,
            'grade': iv.feedback?['grade']?.toString() ?? '',
            'recommendation': iv.feedback?['recommendation']?.toString() ?? '',
            'message_count': 0,
            'started_at': iv.createdAt.toIso8601String(),
          }))),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  Future<void> _delete(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف الجلسة؟' : 'Delete Session?',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(isAr ? 'لا يمكن التراجع.' : 'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(isAr ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await InterviewService().deleteInterview(id);
      ref.invalidate(interviewHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final history = ref.watch(interviewHistoryProvider);
    final authState = ref.watch(authProvider);
    final firstName = authState.user?.fullName.split(' ').first ?? '';
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      // ── NO Stack, NO blobs, clean SafeArea ────────────────────
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // top safe area handled in header padding
        SizedBox(height: MediaQuery.of(context).padding.top),
        // Header
        _Header(
          isDark: isDark,
          isAr: isAr,
          firstName: firstName,
          searching: _searching,
          searchCtrl: _searchCtrl,
          searchFocus: _searchFocus,
          onSearchOpen: _openSearch,
          onSearchClose: _closeSearch,
          onSearchChanged: (v) => setState(() => _query = v),
          onAdd: () => context.push('/interview/setup'),
        ),

        // Body
        Expanded(
            child: history.when(
          loading: () => _Shimmer(isDark: isDark),
          error: (_, __) => _ErrView(
              isDark: isDark,
              isAr: isAr,
              onRetry: () => ref.invalidate(interviewHistoryProvider)),
          data: (raw) {
            final all = raw.map(Interview.fromJson).toList();
            final filtered = _filterList(all);
            final done = all.where((i) => i.isCompleted).toList();
            final scores = done
                .where((i) => i.score != null && i.score! > 0)
                .map((i) => i.score!)
                .toList();
            final avg = scores.isEmpty
                ? 0
                : (scores.reduce((a, b) => a + b) / scores.length).toInt();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Stats card
                SliverToBoxAdapter(
                    child: _StatsCard(
                        total: all.length,
                        done: done.length,
                        avg: avg,
                        isDark: isDark,
                        isAr: isAr)),

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

                // Empty — no sessions at all
                if (all.isEmpty)
                  SliverFillRemaining(
                      child: _EmptyView(
                          isDark: isDark,
                          isAr: isAr,
                          onAdd: () => context.push('/interview/setup'))),

                // Empty — filter has no results
                if (all.isNotEmpty && filtered.isEmpty)
                  SliverFillRemaining(
                      child: Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                        Icon(Icons.search_off_rounded,
                            size: 52,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.08)),
                        const SizedBox(height: 12),
                        Text(isAr ? 'لا توجد نتائج' : 'No results',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 15)),
                      ]))),

                // List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                    (_, i) => _InterviewCard(
                      interview: filtered[i],
                      index: i,
                      isDark: isDark,
                      isAr: isAr,
                      onTap: () => _openReplay(filtered[i]),
                      onDelete: () => _delete(filtered[i].id),
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
// HEADER — your exact style
// ══════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isDark, isAr, searching;
  final String firstName;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final VoidCallback onSearchOpen, onSearchClose, onAdd;
  final ValueChanged<String> onSearchChanged;
  const _Header(
      {required this.isDark,
      required this.isAr,
      required this.firstName,
      required this.searching,
      required this.searchCtrl,
      required this.searchFocus,
      required this.onSearchOpen,
      required this.onSearchClose,
      required this.onSearchChanged,
      required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: searching
              ? _SearchBar(
                  key: const ValueKey('s'),
                  ctrl: searchCtrl,
                  focus: searchFocus,
                  isDark: isDark,
                  isAr: isAr,
                  onChanged: onSearchChanged,
                  onClose: onSearchClose)
              : Row(
                  key: const ValueKey('h'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (firstName.isNotEmpty)
                              Text(
                                  isAr
                                      ? 'مرحباً، $firstName'
                                      : 'Hello, $firstName',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.45)
                                          : Colors.black
                                              .withValues(alpha: 0.40))),
                            Text(isAr ? 'جلساتك' : 'Your Sessions',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1C20))),
                          ]),
                      Row(children: [
                        // Search — styled box like your + button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onSearchOpen();
                          },
                          child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.search_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.70)
                                      : Colors.black.withValues(alpha: 0.60))),
                        ),
                        const SizedBox(width: 10),
                        // Add — your circular violet style
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onAdd();
                          },
                          child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.violet,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.violet
                                          .withValues(alpha: 0.40),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 26)),
                        ),
                      ]),
                    ]),
        ),
      );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool isDark, isAr;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchBar(
      {super.key,
      required this.ctrl,
      required this.focus,
      required this.isDark,
      required this.isAr,
      required this.onChanged,
      required this.onClose});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.28)),
          ),
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: onChanged,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1C20)),
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث...' : 'Search sessions...',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.28)),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: AppColors.violet.withValues(alpha: 0.55)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        )),
        const SizedBox(width: 10),
        GestureDetector(
            onTap: onClose,
            child: Text(isAr ? 'إلغاء' : 'Cancel',
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// STATS CARD — your gradient, all white numbers
// ══════════════════════════════════════════════════════════════════
class _StatsCard extends StatelessWidget {
  final int total, done, avg;
  final bool isDark, isAr;
  const _StatsCard(
      {required this.total,
      required this.done,
      required this.avg,
      required this.isDark,
      required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF5B2BE2), Color(0xFF0EA5E9)],
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
          _SItem(label: isAr ? 'الكل' : 'TOTAL', value: '$total'),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.20)),
          _SItem(label: isAr ? 'مكتمل' : 'DONE', value: '$done'),
          Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.20)),
          _SItem(
              label: isAr ? 'المعدل' : 'AVG', value: avg > 0 ? '$avg%' : '—'),
        ]),
      );
}

class _SItem extends StatelessWidget {
  final String label, value;
  const _SItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
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
// FILTER PILLS — your exact style + localized labels
// ══════════════════════════════════════════════════════════════════
class _FilterPills extends StatelessWidget {
  final _Filter current;
  final bool isDark, isAr;
  final ValueChanged<_Filter> onChange;
  const _FilterPills(
      {required this.current,
      required this.isDark,
      required this.isAr,
      required this.onChange});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
            children: _Filter.values.map((f) {
          final active = f == current;
          return GestureDetector(
            onTap: () => onChange(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                // your exact active/inactive colors
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
              child: Text(f.label(isAr), // ← localized, not f.name
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

// ══════════════════════════════════════════════════════════════════
// INTERVIEW CARD — your structure + swipe delete + chips + date
// ══════════════════════════════════════════════════════════════════
class _InterviewCard extends StatelessWidget {
  final Interview interview;
  final int index;
  final bool isDark, isAr;
  final VoidCallback onTap, onDelete;
  const _InterviewCard(
      {required this.interview,
      required this.index,
      required this.isDark,
      required this.isAr,
      required this.onTap,
      required this.onDelete});

  // Color only for completed sessions with real score
  Color get _ringColor {
    if (!interview.isCompleted ||
        interview.score == null ||
        interview.score! <= 0) {
      return AppColors.violet.withValues(alpha: 0.40); // muted — not yet scored
    }
    final s = interview.score!;
    if (s >= 70) return AppColors.emerald;
    if (s >= 40) return AppColors.amber;
    return AppColors.rose;
  }

  String _diffLabel(bool ar) => switch (interview.difficulty) {
        'easy' => ar ? 'سهل' : 'Easy',
        'medium' => ar ? 'متوسط' : 'Medium',
        'hard' => ar ? 'صعب' : 'Hard',
        _ => interview.difficulty,
      };

  String get _date {
    final d = interview.createdAt.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 16 * (1 - v)), child: child)),
        child: Dismissible(
          key: Key('iv_${interview.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: AppColors.rose, borderRadius: BorderRadius.circular(24)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) async {
            onDelete();
            return false;
          },
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
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(children: [
                // Ring — static, no animation, no dot artifacts
                _Ring(
                    score: interview.score?.toDouble(),
                    isCompleted: interview.isCompleted,
                    ringColor: _ringColor),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(interview.jobRole,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 7),
                      Row(children: [
                        _Chip(_diffLabel(isAr), AppColors.violet),
                        const SizedBox(width: 6),
                        _Chip(interview.interviewType, AppColors.cyan),
                        const Spacer(),
                        Icon(Icons.calendar_today_outlined,
                            size: 10,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.28)
                                : Colors.black.withValues(alpha: 0.28)),
                        const SizedBox(width: 3),
                        Text(_date,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.28)
                                    : Colors.black.withValues(alpha: 0.28))),
                      ]),
                    ])),
                const SizedBox(width: 8),
                Icon(
                    isAr
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.20)),
              ]),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// RING — static, clean, no jank, no artifacts
// Rules:
//   • Not completed → show "–" (dash), muted violet ring at 0
//   • Completed, score null or 0 → show "–", muted ring at 0
//   • Completed, score > 0 → show score, colored ring filled
// ══════════════════════════════════════════════════════════════════
class _Ring extends StatelessWidget {
  final double? score;
  final bool isCompleted;
  final Color ringColor;
  const _Ring({this.score, required this.isCompleted, required this.ringColor});

  bool get _hasScore => isCompleted && score != null && score! > 0;
  double get _value => _hasScore ? (score! / 100).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: Stack(fit: StackFit.expand, children: [
          CircularProgressIndicator(
            value: _value,
            strokeWidth: 4,
            // Always fixed value — no indeterminate (the dot artifact was from null value)
            color: ringColor,
            backgroundColor: ringColor.withValues(alpha: 0.12),
            strokeCap: StrokeCap.round,
          ),
          Center(
              child: _hasScore
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${score!.toInt()}',
                          style: TextStyle(
                              color: ringColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                      Text('%',
                          style: TextStyle(
                              color: ringColor.withValues(alpha: 0.55),
                              fontSize: 7,
                              fontWeight: FontWeight.w700)),
                    ])
                  : Text('—',
                      style: TextStyle(
                          color: isDark(context)
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.30),
                          fontSize: 16,
                          fontWeight: FontWeight.w700))),
        ]),
      );

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

// ══════════════════════════════════════════════════════════════════
// EMPTY + ERROR — styled, not plain
// ══════════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onAdd;
  const _EmptyView(
      {required this.isDark, required this.isAr, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.mic_none_rounded,
                  color: AppColors.violet, size: 40)),
          const SizedBox(height: 18),
          Text(isAr ? 'لا توجد جلسات بعد' : 'No Sessions Yet',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20))),
          const SizedBox(height: 8),
          Text(
              isAr
                  ? 'ابدأ مقابلتك الأولى وطوّر مهاراتك'
                  : 'Start your first interview and level up',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: 0.38))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onAdd();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]),
              child: Text(isAr ? 'ابدأ الآن' : 'Start Now',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ));
}

class _ErrView extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onRetry;
  const _ErrView(
      {required this.isDark, required this.isAr, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.rose),
        const SizedBox(height: 12),
        Text(isAr ? 'فشل التحميل' : 'Failed to load',
            style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.circular(14)),
            child: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ]));
}

// ══════════════════════════════════════════════════════════════════
// SHIMMER — matches actual layout
// ══════════════════════════════════════════════════════════════════
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
            // Header
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            b(70, 11, r: 5),
                            const SizedBox(height: 7),
                            b(160, 26, r: 8, c: hi),
                          ]),
                      Row(children: [
                        b(46, 46, r: 14),
                        const SizedBox(width: 10),
                        b(50, 50, r: 25, c: hi),
                      ]),
                    ])),
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
              b(56, 38, r: 100),
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
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              b(i.isEven ? 130.0 : 110.0, 14, r: 6, c: hi),
                              const SizedBox(height: 8),
                              Row(children: [
                                b(44, 10, r: 5),
                                const SizedBox(width: 6),
                                b(38, 10, r: 5),
                                const Spacer(),
                                b(56, 10, r: 5),
                              ]),
                            ])),
                        const SizedBox(width: 8),
                        b(14, 14, r: 7),
                      ]),
                    )),
          ]),
        );
      });
}
