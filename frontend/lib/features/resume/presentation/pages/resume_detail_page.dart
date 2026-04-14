// lib/features/resume/presentation/pages/resume_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../providers/resume_provider.dart';

class ResumeDetailPage extends ConsumerStatefulWidget {
  final int resumeId;
  final int? goalId;
  final String? targetRole;
  final String? goalTitle;

  const ResumeDetailPage({
    super.key,
    required this.resumeId,
    this.goalId,
    this.targetRole,
    this.goalTitle,
  });

  @override
  ConsumerState<ResumeDetailPage> createState() => _ResumeDetailPageState();
}

class _ResumeDetailPageState extends ConsumerState<ResumeDetailPage> {
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(resumeProvider.notifier).selectResume(widget.resumeId));
  }

  Future<void> _parse() async {
    setState(() => _parsing = true);
    final ok =
        await ref.read(resumeProvider.notifier).parseResume(widget.resumeId);
    if (!mounted) return;
    setState(() => _parsing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Resume parsed!' : 'Parse failed. Try again.'),
      backgroundColor: ok ? AppColors.emerald : AppColors.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _go(String feature) {
    HapticFeedback.lightImpact();
    context.push(
      '/resume/${widget.resumeId}/$feature',
      extra: {
        'goalId': widget.goalId,
        'targetRole': widget.targetRole,
        'goalTitle': widget.goalTitle,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeProvider);
    final resume = state.selectedResume;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: MediaQuery.of(context).padding.top),

        // ── Top bar ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(children: [
            IconButton(
              icon: Icon(
                isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                size: 28,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.60)
                    : Colors.black.withValues(alpha: 0.55),
              ),
              onPressed: () => context.go('/resume'),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'السيرة الذاتية' : 'Resume Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.40),
                      ),
                    ),
                    Text(
                      resume?.title ?? (state.isLoading ? '' : 'Resume'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1A1C20),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────
        Expanded(
          child: (state.isLoading || resume == null)
              ? _Shimmer(isDark: isDark)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(children: [
                    // ── Stats card (same gradient as interview list) ──
                    _InfoCard(
                      resume: resume,
                      isDark: isDark,
                      isAr: isAr,
                      parsing: _parsing,
                      onParse: _parsing ? null : _parse,
                    ),

                    // ── Goal banner ──────────────────────────────
                    if (widget.goalId != null) ...[
                      const SizedBox(height: 12),
                      _GoalBanner(
                        goalId: widget.goalId!,
                        targetRole: widget.targetRole ?? '',
                        goalTitle: widget.goalTitle ?? '',
                        isDark: isDark,
                        isAr: isAr,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── TOOLS label ──────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (isAr ? 'الأدوات' : 'TOOLS').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Feature tiles ───────────────────────────
                    _Tile(
                      icon: Icons.auto_fix_high_rounded,
                      label: isAr ? 'تحسين السيرة الذاتية' : 'Enhance Resume',
                      sub: isAr
                          ? 'تحليل ذكي وتحسينات'
                          : 'AI analysis & suggestions',
                      color: AppColors.violet,
                      isDark: isDark,
                      isAr: isAr,
                      locked: !resume.isParsed,
                      onTap: () => _go('enhance'),
                    ),
                    _Tile(
                      icon: Icons.fact_check_rounded,
                      label: 'ATS Check',
                      sub: isAr
                          ? 'درجة وإصلاح التوافق'
                          : 'Grade, issues & fixes',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      isAr: isAr,
                      locked: !resume.isParsed,
                      onTap: () => _go('ats'),
                    ),
                    _Tile(
                      icon: Icons.compare_arrows_rounded,
                      label: isAr ? 'مطابقة الوظيفة' : 'Job Match',
                      sub: isAr
                          ? 'الصق الوصف واحصل على نسبة التطابق'
                          : 'Paste job & get match score',
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                      isAr: isAr,
                      locked: !resume.isParsed,
                      onTap: () => _go('match'),
                    ),
                    _Tile(
                      icon: Icons.draw_rounded,
                      label: isAr ? 'بناء وتصميم' : 'Build & Design',
                      sub: isAr
                          ? 'أنشئ DOCX أو PDF احترافي'
                          : 'Create polished DOCX or PDF',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                      isAr: isAr,
                      locked: false,
                      onTap: () => _go('build'),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// INFO CARD — slim gradient like interview stats card
// ══════════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final dynamic resume;
  final bool isDark, isAr, parsing;
  final VoidCallback? onParse;

  const _InfoCard({
    required this.resume,
    required this.isDark,
    required this.isAr,
    required this.parsing,
    this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final isParsed = resume.isParsed as bool;
    final isPdf = resume.fileType?.toLowerCase() == 'pdf';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B2BE2), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7B3FE4).withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File icon + title + badges
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(resume.title ?? 'Resume',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                _badge(resume.fileType?.toUpperCase() ?? 'FILE',
                    Colors.white.withValues(alpha: 0.25), Colors.white),
                const SizedBox(width: 6),
                _badge(
                  isParsed
                      ? (isAr ? '✓ محلَّل' : '✓ Parsed')
                      : (isAr ? 'يحتاج تحليل' : 'Needs Parse'),
                  isParsed
                      ? const Color(0xFF5EEAD4).withValues(alpha: 0.25)
                      : const Color(0xFFFBBF24).withValues(alpha: 0.25),
                  isParsed ? const Color(0xFF5EEAD4) : const Color(0xFFFBBF24),
                ),
                if (resume.atsScore != null) ...[
                  const SizedBox(width: 6),
                  _badge(
                      'ATS ${resume.atsScore}%',
                      const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                      const Color(0xFF7DD3FC)),
                ],
              ]),
            ]),
          ),
        ]),

        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          child:
              Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat(
                isAr ? 'الحالة' : 'STATUS',
                isParsed
                    ? (isAr ? 'جاهز' : 'Ready')
                    : (isAr ? 'معلَّق' : 'Pending')),
            Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.20)),
            _stat(
                isAr ? 'النوع' : 'TYPE', resume.fileType?.toUpperCase() ?? '—'),
            Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.20)),
            _stat(isAr ? 'الإضافة' : 'ADDED', _date(resume.createdAt)),
          ]),
        ),

        // Parse button — only when not parsed
        if (!isParsed) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onParse,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (parsing)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  parsing
                      ? (isAr ? 'جارٍ التحليل...' : 'Parsing...')
                      : (isAr ? 'تحليل السيرة' : 'Parse Resume'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _badge(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(t,
            style: TextStyle(
                color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _stat(String label, String value) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]);

  String _date(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ══════════════════════════════════════════════════════════════════
// FEATURE TILE — interview card style
// ══════════════════════════════════════════════════════════════════
class _Tile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final bool isDark, isAr, locked;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.isDark,
    required this.isAr,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: locked ? null : onTap,
          child: Container(
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: locked ? 0.06 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: color.withValues(alpha: locked ? 0.35 : 1.0),
                    size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark
                                ? (locked
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.white)
                                : (locked
                                    ? Colors.black87.withValues(alpha: 0.35)
                                    : Colors.black87),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [
                        _c(isAr ? 'الذكاء الاصطناعي' : 'AI', AppColors.violet),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(sub,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white
                                        .withValues(alpha: locked ? 0.20 : 0.45)
                                    : Colors.black.withValues(
                                        alpha: locked ? 0.20 : 0.45),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ]),
              ),
              const SizedBox(width: 8),
              if (locked)
                Icon(Icons.lock_rounded,
                    size: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.18))
              else
                Icon(
                  isAr
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.black.withValues(alpha: 0.20),
                ),
            ]),
          ),
        ),
      );

  Widget _c(String t, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: col.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(5)),
        child: Text(t,
            style: TextStyle(
                color: col, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

// ══════════════════════════════════════════════════════════════════
// GOAL BANNER
// ══════════════════════════════════════════════════════════════════
class _GoalBanner extends StatelessWidget {
  final int goalId;
  final String targetRole, goalTitle;
  final bool isDark, isAr;

  const _GoalBanner({
    required this.goalId,
    required this.targetRole,
    required this.goalTitle,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final display = targetRole.isNotEmpty ? targetRole : goalTitle;
    return GestureDetector(
      onTap: () => context.push('/goals/$goalId'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.violet, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                (isAr ? 'هدفك النشط' : 'ACTIVE GOAL').toUpperCase(),
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8),
              ),
              Text(display,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.20)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHIMMER — mirrors detail page layout exactly
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info card skeleton (mirrors gradient card shape)
            Container(
              height: 190,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(26)),
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      b(52, 52, r: 26, c: hi),
                      const SizedBox(width: 14),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            b(130, 14, r: 6, c: hi),
                            const SizedBox(height: 8),
                            Row(children: [
                              b(36, 10, r: 5),
                              const SizedBox(width: 6),
                              b(56, 10, r: 5),
                            ]),
                          ]),
                    ]),
                    const SizedBox(height: 16),
                    b(double.infinity, 1,
                        r: 0, c: Colors.white.withValues(alpha: 0.18)),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          b(50, 30, r: 6, c: hi),
                          b(1, 36, c: Colors.white.withValues(alpha: 0.18)),
                          b(40, 30, r: 6, c: hi),
                          b(1, 36, c: Colors.white.withValues(alpha: 0.18)),
                          b(44, 30, r: 6, c: hi),
                        ]),
                  ]),
            ),

            const SizedBox(height: 28),
            b(54, 11, r: 5), // TOOLS label
            const SizedBox(height: 14),

            // 4 feature tile skeletons (match actual tile layout)
            ...List.generate(
                4,
                (i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                        b(50, 50, r: 25, c: hi), // circle icon
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              b(i.isEven ? 140.0 : 110.0, 14, r: 6, c: hi),
                              const SizedBox(height: 8),
                              Row(children: [
                                b(28, 9, r: 4),
                                const SizedBox(width: 5),
                                b(i.isEven ? 100.0 : 80.0, 9, r: 4),
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
