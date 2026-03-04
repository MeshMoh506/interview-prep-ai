import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/background_painter.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/screens/login_screen.dart'; // GlassCard, PrimaryButton
import '../../providers/resume_provider.dart';
import 'resume_design_tab.dart';

class ResumeDetailPage extends ConsumerStatefulWidget {
  final int resumeId;
  const ResumeDetailPage({super.key, required this.resumeId});

  @override
  ConsumerState<ResumeDetailPage> createState() => _ResumeDetailPageState();
}

class _ResumeDetailPageState extends ConsumerState<ResumeDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  Map<String, dynamic>? _analysisResult,
      _atsResult,
      _matchResult,
      _questionsResult,
      _radarResult,
      _variantsResult;

  bool _parsing = false,
      _analyzing = false,
      _checking = false,
      _matching = false;
  bool _predicting = false;

  final _jobDescCtrl = TextEditingController();
  final _predictRoleCtrl = TextEditingController();
  final _targetRoleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    Future.microtask(
        () => ref.read(resumeProvider.notifier).selectResume(widget.resumeId));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _jobDescCtrl.dispose();
    _predictRoleCtrl.dispose();
    _targetRoleCtrl.dispose();
    super.dispose();
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────────

  Future<void> _parse() async {
    setState(() => _parsing = true);
    final ok =
        await ref.read(resumeProvider.notifier).parseResume(widget.resumeId);
    if (!mounted) return;
    setState(() => _parsing = false);
    _snack(ok ? '✅ Parsed with AI!' : '❌ Parse failed', isError: !ok);
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final result = await ref.read(resumeProvider.notifier).analyzeResume(
          widget.resumeId,
          targetRole:
              _targetRoleCtrl.text.isEmpty ? null : _targetRoleCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _analysisResult = result;
    });
  }

  Future<void> _checkAts() async {
    setState(() => _checking = true);
    final result =
        await ref.read(resumeProvider.notifier).checkAts(widget.resumeId);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _atsResult = result;
    });
  }

  Future<void> _matchJob() async {
    if (_jobDescCtrl.text.isEmpty) return;
    setState(() => _matching = true);
    final result = await ref
        .read(resumeProvider.notifier)
        .matchJob(widget.resumeId, _jobDescCtrl.text);
    if (!mounted) return;
    setState(() {
      _matching = false;
      _matchResult = result;
    });
  }

  Future<void> _getRadarScore() async {
    final result = await ref
        .read(resumeServiceProvider)
        .getRadarScore(widget.resumeId, _targetRoleCtrl.text);
    if (!mounted) return;
    setState(() => _radarResult = result);
  }

  Future<void> _generateVariants() async {
    final result =
        await ref.read(resumeServiceProvider).generateVariants(widget.resumeId);
    if (!mounted) return;
    setState(() => _variantsResult = result);
  }

  Future<void> _predictQuestions() async {
    if (_predictRoleCtrl.text.isEmpty) return;
    setState(() => _predicting = true);
    final result = await ref
        .read(resumeServiceProvider)
        .predictQuestions(widget.resumeId, _predictRoleCtrl.text);
    if (!mounted) return;
    setState(() {
      _predicting = false;
      _questionsResult = result;
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.rose : AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeProvider);
    final resume = state.selectedResume;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isLoading || resume == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: Stack(
        children: [
          const BackgroundPainter(),
          ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                _buildAppBar(resume, isDark),
                _buildTabBar(isDark),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _wrapper(_detailsTab(resume, isDark)),
                  _wrapper(_analysisTab(resume, isDark)),
                  _wrapper(_atsTab(resume, isDark)),
                  _wrapper(_jobMatchTab(resume, isDark)),
                  ResumeDesignTab(resume: resume, isDark: isDark),
                  _wrapper(_aiPowerTab(resume, isDark)),
                  _wrapper(_predictTab(resume, isDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapper(Widget child) => LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 140,
              maxWidth: 500,
            ),
            child: Center(
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      );

  Widget _buildAppBar(dynamic resume, bool isDark) => SliverAppBar(
        pinned: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go('/resume')),
        title: Text(resume.title ?? 'Analysis',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        flexibleSpace: ClipRRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.4)))),
      );

  Widget _buildTabBar(bool isDark) => SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
          child: ClipRRect(
              child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.8),
                      child: TabBar(
                          controller: _tabs,
                          isScrollable: true,
                          indicatorColor: AppColors.violet,
                          labelColor: AppColors.violet,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 11),
                          tabs: const [
                            Tab(text: 'INFO'),
                            Tab(text: 'ANALYSIS'),
                            Tab(text: 'ATS'),
                            Tab(text: 'MATCH'),
                            Tab(text: 'DESIGN'),
                            Tab(text: 'AI POWER'),
                            Tab(text: 'PREDICT')
                          ]))))));

  // ── TAB VIEWS ─────────────────────────────────────────────────────────────

  Widget _detailsTab(dynamic resume, bool isDark) => Column(children: [
        _InfoCard(
            title: 'Resume Info',
            icon: Icons.info_outline,
            isDark: isDark,
            child: Column(children: [
              _row('Type', resume.fileType?.toUpperCase() ?? '—'),
              _row('Status', resume.isParsed ? '✅ Ready' : '❌ Needs AI Parse'),
              _row('Added', _fmtDate(resume.createdAt))
            ])),
        const SizedBox(height: 20),
        GlassCard(
            isDark: isDark,
            child: Column(children: [
              _ActionTile(
                  label: 'Parse Resume',
                  sub: 'Extract Data with AI',
                  icon: Icons.auto_awesome,
                  color: Colors.blue,
                  loading: _parsing,
                  onTap: _parse),
              const Divider(height: 32, color: Colors.white10),
              _ActionTile(
                  label: 'Full Audit',
                  sub: 'AI quality score',
                  icon: Icons.analytics,
                  color: AppColors.emerald,
                  loading: _analyzing,
                  onTap: resume.isParsed ? _analyze : null),
            ])),
      ]);

  // ── ANALYSIS TAB ─────────────────────────────────────────────────────────
  // Backend: { overall_score, summary, strengths[], weaknesses[],
  //            ats_score, ats_issues[], missing_sections[],
  //            improvement_suggestions[], keyword_recommendations[] }

  Widget _analysisTab(dynamic resume, bool isDark) {
    if (!resume.isParsed) {
      return _cta('Parse First', 'Go to INFO tab and parse your resume',
          () => _tabs.animateTo(0), isDark);
    }
    if (_analysisResult == null) {
      return Column(children: [
        GlassCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TARGET ROLE (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              TextField(
                controller: _targetRoleCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter Developer, Data Scientist...',
                  prefixIcon: const Icon(Icons.work_rounded,
                      color: AppColors.violet, size: 18),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Run AI Analysis',
                  isLoading: _analyzing,
                  onTap: _analyze),
            ],
          ),
        ),
      ]);
    }

    final r = _analysisResult!;
    // Score: backend sends 0-10 directly (e.g. 7)
    final score = (r['overall_score'] ?? 0).toDouble();
    final atsScore = (r['ats_score'] ?? 0).toDouble();
    final strengths = (r['strengths'] as List?) ?? [];
    final weaknesses = (r['weaknesses'] as List?) ?? [];
    final atsissues = (r['ats_issues'] as List?) ?? [];
    final missingSections = (r['missing_sections'] as List?) ?? [];
    final suggestions = (r['improvement_suggestions'] as List?) ?? [];
    final keywords = (r['keyword_recommendations'] as List?) ?? [];
    final summary = r['summary']?.toString() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Score row ──
      _ScoreCard(score: score, title: 'AI Quality', isDark: isDark),
      const SizedBox(height: 12),
      _ScoreCard(score: atsScore, title: 'ATS Score', isDark: isDark),

      // ── Summary ──
      if (summary.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'SUMMARY',
          icon: Icons.summarize_rounded,
          isDark: isDark,
          child:
              Text(summary, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],

      // ── Strengths ──
      if (strengths.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'STRENGTHS',
          icon: Icons.star_border_rounded,
          isDark: isDark,
          child: _bullets(
              strengths.map((s) => s.toString()).toList(), AppColors.emerald),
        ),
      ],

      // ── Weaknesses ──
      if (weaknesses.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'WEAKNESSES',
          icon: Icons.warning_amber_rounded,
          isDark: isDark,
          child: _bullets(
              weaknesses.map((s) => s.toString()).toList(), AppColors.rose),
        ),
      ],

      // ── Missing Sections ──
      if (missingSections.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'MISSING SECTIONS',
          icon: Icons.playlist_remove_rounded,
          isDark: isDark,
          child: _bullets(missingSections.map((s) => s.toString()).toList(),
              AppColors.amber),
        ),
      ],

      // ── Improvement Suggestions ──
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'IMPROVEMENT SUGGESTIONS',
          icon: Icons.lightbulb_outline_rounded,
          isDark: isDark,
          child: Column(
            children: suggestions.map<Widget>((s) {
              final section = s is Map ? s['section']?.toString() ?? '' : '';
              final issue = s is Map ? s['issue']?.toString() ?? '' : '';
              final suggestion = s is Map
                  ? s['suggestion']?.toString() ?? s.toString()
                  : s.toString();
              final priority = s is Map ? s['priority']?.toString() ?? '' : '';
              final example = s is Map ? s['example']?.toString() ?? '' : '';

              Color priorityColor = AppColors.amber;
              if (priority == 'high') priorityColor = AppColors.rose;
              if (priority == 'low') priorityColor = AppColors.emerald;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: priorityColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (section.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(section,
                                style: const TextStyle(
                                    color: AppColors.violet,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (priority.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(priority.toUpperCase(),
                                style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900)),
                          ),
                      ]),
                      if (issue.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(issue,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey)),
                      ],
                      const SizedBox(height: 4),
                      Text(suggestion,
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                      if (example.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 ',
                                    style: TextStyle(fontSize: 11)),
                                Expanded(
                                    child: Text(example,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.emerald,
                                            height: 1.4))),
                              ]),
                        ),
                      ],
                    ]),
              );
            }).toList(),
          ),
        ),
      ],

      // ── ATS Issues ──
      if (atsissues.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'ATS ISSUES',
          icon: Icons.find_replace_rounded,
          isDark: isDark,
          child: _bullets(
              atsissues.map((s) => s.toString()).toList(), AppColors.rose),
        ),
      ],

      // ── Keyword Recommendations ──
      if (keywords.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'RECOMMENDED KEYWORDS',
          icon: Icons.label_rounded,
          isDark: isDark,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .map<Widget>((k) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.violet.withValues(alpha: 0.3)),
                      ),
                      child: Text(k.toString(),
                          style: const TextStyle(
                              color: AppColors.violet,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ),
      ],

      // ── Re-run ──
      const SizedBox(height: 20),
      PrimaryButton(
          label: 'Re-analyze', isLoading: _analyzing, onTap: _analyze),
    ]);
  }

  // ── ATS TAB ──────────────────────────────────────────────────────────────
  // Backend returns DIRECTLY (no wrapper):
  // { format_score, grade, grade_label, total_issues, total_warnings,
  //   total_passed, critical_issues[], warnings[], passed_checks[],
  //   summary, top_priority, recommendations: { immediate[], suggested[] } }

  Widget _atsTab(dynamic resume, bool isDark) {
    if (_atsResult == null) {
      return _cta('ATS Compatibility', 'Check ATS Score', _checkAts, isDark);
    }

    final score = (_atsResult!['format_score'] ?? 0).toDouble();
    final grade = _atsResult!['grade']?.toString() ?? '';
    final gradeLabel = _atsResult!['grade_label']?.toString() ?? '';
    final summary = _atsResult!['summary']?.toString() ?? '';
    final topPriority = _atsResult!['top_priority']?.toString() ?? '';
    final totalPassed = _atsResult!['total_passed'] ?? 0;
    final totalWarnings = _atsResult!['total_warnings'] ?? 0;
    final totalIssues = _atsResult!['total_issues'] ?? 0;

    final criticalIssues = (_atsResult!['critical_issues'] as List?) ?? [];
    final warnings = (_atsResult!['warnings'] as List?) ?? [];
    final passedChecks = (_atsResult!['passed_checks'] as List?) ?? [];
    final recs = _atsResult!['recommendations'] as Map<String, dynamic>?;
    final immediate = (recs?['immediate'] as List?) ?? [];
    final suggested = (recs?['suggested'] as List?) ?? [];

    // Grade color
    Color gradeColor = AppColors.emerald;
    if (grade == 'D' || grade == 'F') gradeColor = AppColors.rose;
    if (grade == 'C') gradeColor = AppColors.amber;
    if (grade == 'B') gradeColor = AppColors.cyan;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Score + Grade ──
      GlassCard(
        isDark: isDark,
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 7,
                color: gradeColor,
                backgroundColor: Colors.white10,
              ),
            ),
            Text('${score.toInt()}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('ATS Pass Rate',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$grade — $gradeLabel',
                      style: TextStyle(
                          color: gradeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 6),
              if (summary.isNotEmpty)
                Text(summary,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ]),
      ),

      // ── Stats row ──
      const SizedBox(height: 12),
      Row(children: [
        _statPill('$totalPassed Passed', AppColors.emerald),
        const SizedBox(width: 8),
        _statPill('$totalWarnings Warnings', AppColors.amber),
        const SizedBox(width: 8),
        _statPill('$totalIssues Issues', AppColors.rose),
      ]),

      // ── Top Priority ──
      if (topPriority.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.rose.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.priority_high_rounded,
                color: AppColors.rose, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('TOP PRIORITY',
                      style: TextStyle(
                          color: AppColors.rose,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(topPriority,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ])),
          ]),
        ),
      ],

      // ── Critical Issues ──
      if (criticalIssues.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'CRITICAL ISSUES',
          icon: Icons.error_outline_rounded,
          isDark: isDark,
          child: Column(
            children: criticalIssues.map<Widget>((i) {
              final issue =
                  i is Map ? (i['issue'] ?? i.toString()) : i.toString();
              final detail = i is Map ? i['detail']?.toString() ?? '' : '';
              final fix = i is Map ? i['fix']?.toString() ?? '' : '';
              return _issueCard(issue, detail, fix, AppColors.rose);
            }).toList(),
          ),
        ),
      ],

      // ── Warnings ──
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'WARNINGS',
          icon: Icons.warning_amber_rounded,
          isDark: isDark,
          child: Column(
            children: warnings.map<Widget>((w) {
              final issue =
                  w is Map ? (w['issue'] ?? w.toString()) : w.toString();
              final detail = w is Map ? w['detail']?.toString() ?? '' : '';
              final fix = w is Map ? w['fix']?.toString() ?? '' : '';
              return _issueCard(issue, detail, fix, AppColors.amber);
            }).toList(),
          ),
        ),
      ],

      // ── Passed Checks ──
      if (passedChecks.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'PASSED CHECKS',
          icon: Icons.check_circle_outline_rounded,
          isDark: isDark,
          child: Column(
            children: passedChecks
                .map<Widget>((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.toString(),
                                style: const TextStyle(
                                    fontSize: 12, height: 1.3))),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ],

      // ── Immediate Recommendations ──
      if (immediate.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'DO NOW',
          icon: Icons.bolt_rounded,
          isDark: isDark,
          child: _bullets(
              immediate.map((s) => s.toString()).toList(), AppColors.rose),
        ),
      ],

      // ── Suggested Improvements ──
      if (suggested.isNotEmpty) ...[
        const SizedBox(height: 16),
        _InfoCard(
          title: 'SUGGESTED IMPROVEMENTS',
          icon: Icons.lightbulb_outline_rounded,
          isDark: isDark,
          child: _bullets(
              suggested.map((s) => s.toString()).toList(), AppColors.amber),
        ),
      ],

      // ── Re-check ──
      const SizedBox(height: 20),
      PrimaryButton(
          label: 'Re-check ATS', isLoading: _checking, onTap: _checkAts),
    ]);
  }

  Widget _statPill(String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _issueCard(String issue, String detail, String fix, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle, color: color, size: 8),
            const SizedBox(width: 8),
            Expanded(
                child: Text(issue,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(detail,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, height: 1.3)),
            ),
          ],
          if (fix.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.arrow_right_rounded,
                    color: AppColors.emerald, size: 16),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(fix,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.emerald,
                            height: 1.3))),
              ]),
            ),
          ],
        ]),
      );

  Widget _jobMatchTab(dynamic resume, bool isDark) {
    final matched = (_matchResult?['matched_keywords'] as List?) ?? [];
    final missingK = (_matchResult?['missing_keywords'] as List?) ?? [];
    final strengths = (_matchResult?['strengths'] as List?) ?? [];
    final gaps = (_matchResult?['gaps'] as List?) ?? [];

    return Column(children: [
      GlassCard(
          isDark: isDark,
          child: Column(children: [
            const Text('JOB MATCHING',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            TextField(
                controller: _jobDescCtrl,
                maxLines: 5,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                    hintText: 'Paste Job Description...',
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Match Now', isLoading: _matching, onTap: _matchJob),
          ])),
      if (_matchResult != null) ...[
        const SizedBox(height: 20),
        _ScoreCard(
            score: (_matchResult!['match_score'] ?? 0).toDouble(),
            title: 'Job Fit Score',
            isDark: isDark),
        if (_matchResult!['match_level'] != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            isDark: isDark,
            child: Row(children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.violet),
              const SizedBox(width: 12),
              const Text('Match Level: ',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text(_matchResult!['match_level'].toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.violet,
                      fontSize: 15)),
            ]),
          ),
        ],
        if (_matchResult!['recommendation'] != null) ...[
          const SizedBox(height: 12),
          _InfoCard(
              title: 'Recommendation',
              icon: Icons.recommend_rounded,
              isDark: isDark,
              child: Text(_matchResult!['recommendation'].toString(),
                  style: const TextStyle(height: 1.5, fontSize: 13))),
        ],
        if (matched.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoCard(
              title: 'Matched Keywords',
              icon: Icons.check_circle_outline_rounded,
              isDark: isDark,
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: matched
                      .map<Widget>((k) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(k.toString(),
                                style: const TextStyle(
                                    color: AppColors.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ))
                      .toList())),
        ],
        if (missingK.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoCard(
              title: 'Missing Keywords',
              icon: Icons.label_off_rounded,
              isDark: isDark,
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: missingK
                      .map<Widget>((k) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(k.toString(),
                                style: const TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ))
                      .toList())),
        ],
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoCard(
              title: 'Your Strengths',
              icon: Icons.star_border_rounded,
              isDark: isDark,
              child: _bullets(strengths.map((s) => s.toString()).toList(),
                  AppColors.emerald)),
        ],
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoCard(
              title: 'Skill Gaps',
              icon: Icons.construction_rounded,
              isDark: isDark,
              child: _bullets(
                  gaps.map((g) => g.toString()).toList(), AppColors.amber)),
        ],
      ],
    ]);
  }

  Widget _aiPowerTab(dynamic resume, bool isDark) => Column(children: [
        if (_radarResult != null)
          GlassCard(
              isDark: isDark,
              child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: _RadarChartPainter(
                          dimensions: (_radarResult!['dimensions']
                                  as Map<String, dynamic>?) ??
                              {},
                          isDark: isDark)))),
        const SizedBox(height: 20),
        _cta('Skill Analytics', 'Generate Radar Chart', _getRadarScore, isDark),
        const SizedBox(height: 20),
        _cta('Variants', 'Generate Tone Variants', _generateVariants, isDark),
        if (_variantsResult != null)
          ...['Aggressive', 'Professional', 'Technical'].map((v) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GlassCard(
                  isDark: isDark,
                  child: Row(children: [
                    Text(v,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Icon(Icons.download, size: 18)
                  ])))),
      ]);

  Widget _predictTab(dynamic resume, bool isDark) {
    final qData = (_questionsResult?['data'] as Map<String, dynamic>?) ??
        _questionsResult ??
        {};
    final techQ = (qData['technical_questions'] as List?) ?? [];
    final behavQ = (qData['behavioral_questions'] as List?) ?? [];
    final gapQ = (qData['gap_questions'] as List?) ?? [];
    final strengthQ = (qData['strength_questions'] as List?) ?? [];
    final tips = (qData['overall_interview_tips'] as List?) ?? [];
    final situQ = (qData['situational_questions'] as List?) ?? [];

    Widget questionCard(dynamic q, Color accent) {
      final text = q is Map
          ? (q['question'] ?? q['text'] ?? q.toString())
          : q.toString();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          isDark: isDark,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text.toString(),
                    style: const TextStyle(fontSize: 13, height: 1.4))),
          ]),
        ),
      );
    }

    return Column(children: [
      GlassCard(
          isDark: isDark,
          child: Column(children: [
            const Text('QUESTION PREDICTOR',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            TextField(
                controller: _predictRoleCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                    hintText: 'Target Role...',
                    prefixIcon: const Icon(Icons.work_rounded),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Predict Now',
                isLoading: _predicting,
                onTap: _predictQuestions),
          ])),
      if (_questionsResult != null) ...[
        if (techQ.isNotEmpty) ...[
          const SizedBox(height: 20),
          _InfoCard(
              title: 'Technical Questions',
              icon: Icons.code_rounded,
              isDark: isDark,
              child: Column(
                  children: techQ
                      .map((q) => questionCard(q, AppColors.violet))
                      .toList())),
        ],
        if (behavQ.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
              title: 'Behavioral Questions',
              icon: Icons.psychology_rounded,
              isDark: isDark,
              child: Column(
                  children: behavQ
                      .map((q) => questionCard(q, AppColors.cyan))
                      .toList())),
        ],
        if (situQ.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
              title: 'Situational Questions',
              icon: Icons.lightbulb_outline_rounded,
              isDark: isDark,
              child: Column(
                  children: situQ
                      .map((q) => questionCard(q, AppColors.amber))
                      .toList())),
        ],
        if (gapQ.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
              title: 'Gap Questions',
              icon: Icons.help_outline_rounded,
              isDark: isDark,
              child: Column(
                  children: gapQ
                      .map((q) => questionCard(q, AppColors.rose))
                      .toList())),
        ],
        if (strengthQ.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
              title: 'Strength Questions',
              icon: Icons.star_outline_rounded,
              isDark: isDark,
              child: Column(
                  children: strengthQ
                      .map((q) => questionCard(q, AppColors.emerald))
                      .toList())),
        ],
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
              title: 'Interview Tips',
              icon: Icons.tips_and_updates_rounded,
              isDark: isDark,
              child: _bullets(
                  tips.map((t) => t.toString()).toList(), AppColors.violet)),
        ],
        if (techQ.isEmpty &&
            behavQ.isEmpty &&
            situQ.isEmpty &&
            gapQ.isEmpty) ...[
          const SizedBox(height: 20),
          GlassCard(
              isDark: isDark,
              child: const Center(
                  child: Text(
                      'No questions returned. Try a more specific role.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))),
        ],
      ],
    ]);
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _cta(String title, String btn, VoidCallback onTap, bool isDark) =>
      GlassCard(
          isDark: isDark,
          child: Column(children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 16),
            PrimaryButton(label: btn, isLoading: false, onTap: onTap)
          ]));

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(v,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
      ]));

  Widget _bullets(List<String> items, Color c) => Column(
      children: items
          .map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle, color: c, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(i,
                        style: const TextStyle(fontSize: 12, height: 1.4)))
              ])))
          .toList());

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final Widget child;
  const _InfoCard(
      {required this.title,
      required this.icon,
      required this.isDark,
      required this.child});

  @override
  Widget build(BuildContext context) => GlassCard(
      isDark: isDark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.violet),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1))
        ]),
        const SizedBox(height: 16),
        child
      ]));
}

class _ScoreCard extends StatelessWidget {
  final double score;
  final String title;
  final bool isDark;
  const _ScoreCard(
      {required this.score, required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) => GlassCard(
      isDark: isDark,
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                  value: score / 10,
                  strokeWidth: 6,
                  color: AppColors.violet,
                  backgroundColor: Colors.white10)),
          Text('${score.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))
        ]),
        const SizedBox(width: 20),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const Text('AI Score Metric',
                style: TextStyle(color: Colors.grey, fontSize: 11))
          ]),
        )
      ]));
}

class _ActionTile extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _ActionTile(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.color,
      required this.loading,
      this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11))
        ])),
        loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey)
      ]));
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  Widget build(BuildContext context, double offset, bool overlaps) => child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate old) => false;
}

class _RadarChartPainter extends CustomPainter {
  final Map<String, dynamic> dimensions;
  final bool isDark;
  const _RadarChartPainter({required this.dimensions, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final validKeys =
        dimensions.keys.where((k) => dimensions[k] is Map).toList();
    if (validKeys.isEmpty) return;
    final step = (2 * math.pi) / validKeys.length;

    final grid = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke;

    for (int l = 1; l <= 5; l++) {
      final r = radius * l / 5;
      final p = Path();
      for (int i = 0; i <= validKeys.length; i++) {
        final a = -math.pi / 2 + i * step;
        final x = center.dx + r * math.cos(a);
        final y = center.dy + r * math.sin(a);
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      canvas.drawPath(p..close(), grid);
    }

    final data = Path();
    for (int i = 0; i < validKeys.length; i++) {
      final dim = dimensions[validKeys[i]] as Map<String, dynamic>;
      final s = ((dim['score'] as num?)?.toDouble() ?? 0) / 100;
      final a = -math.pi / 2 + i * step;
      final x = center.dx + (radius * s) * math.cos(a);
      final y = center.dy + (radius * s) * math.sin(a);
      i == 0 ? data.moveTo(x, y) : data.lineTo(x, y);
    }
    canvas.drawPath(data..close(),
        Paint()..color = AppColors.violet.withValues(alpha: 0.2));
    canvas.drawPath(
        data,
        Paint()
          ..color = AppColors.violet
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}
