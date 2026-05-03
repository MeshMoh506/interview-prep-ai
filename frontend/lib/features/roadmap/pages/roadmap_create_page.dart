// lib/features/roadmap/pages/roadmap_create_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../resume/providers/resume_provider.dart';
import '../providers/roadmap_provider.dart';

class RoadmapCreatePage extends ConsumerStatefulWidget {
  const RoadmapCreatePage({super.key});
  @override
  ConsumerState<RoadmapCreatePage> createState() => _RoadmapCreatePageState();
}

class _RoadmapCreatePageState extends ConsumerState<RoadmapCreatePage> {
  final _roleCtrl = TextEditingController();
  String _difficulty = 'intermediate';
  String _pathType = 'balanced';
  bool _includeCapstone = true;
  int _hoursPerWeek = 10;
  int _targetWeeks = 8;
  int? _resumeId;
  bool _isGenerating = false;

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    if (_roleCtrl.text.trim().isEmpty) {
      _snack(isAr ? 'أدخل الدور المستهدف' : 'Please enter a target role');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);

    final success = await ref.read(roadmapListProvider.notifier).generate(
          targetRole: _roleCtrl.text.trim(),
          difficulty: _difficulty,
          resumeId: _resumeId,
          pathType: _pathType,
          includeCapstone: _includeCapstone,
          hoursPerWeek: _hoursPerWeek,
          targetWeeks: _targetWeeks,
        );

    if (!mounted) return;
    setState(() => _isGenerating = false);

    if (success) {
      final roadmaps = ref.read(roadmapListProvider).roadmaps;
      context.go(
          roadmaps.isNotEmpty ? '/roadmap/${roadmaps.last.id}' : '/roadmap');
    } else {
      final isArNow = Directionality.of(context) == TextDirection.rtl;
      _snack(ref.read(roadmapListProvider).error ??
          (isArNow ? 'فشل إنشاء الخارطة' : 'Failed to generate'));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  String _pathLabel(bool ar) => switch (_pathType) {
        'certification' => ar ? 'شهادات' : 'Certification',
        'project' => ar ? 'مشاريع' : 'Projects',
        _ => ar ? 'متوازن' : 'Balanced',
      };

  String _diffLabel(bool ar) => switch (_difficulty) {
        'beginner' => ar ? 'مبتدئ' : 'Beginner',
        'advanced' => ar ? 'متقدم' : 'Advanced',
        _ => ar ? 'متوسط' : 'Intermediate',
      };

  @override
  Widget build(BuildContext context) {
    final resumesAsync = ref.watch(resumesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        SizedBox(height: top + 12),

        // ── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
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
                    isAr
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 22,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : Colors.black.withValues(alpha: 0.55)),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              isAr ? 'إنشاء خارطة' : 'Create Roadmap',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20)),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Scrollable body ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero card ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF6D28D9).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'مسار التعلم بالذكاء' : 'AI Learning Path',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr
                                  ? 'خطة مخصصة لأهدافك وجدولك'
                                  : 'Tailored to your goals and schedule',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Target role ────────────────────────────
                _lbl(isAr ? 'الدور المستهدف' : 'Target Role', isDark),
                const SizedBox(height: 8),
                _InputField(
                  controller: _roleCtrl,
                  hint: isAr ? 'مثال: مطور Flutter' : 'e.g. Flutter Developer',
                  icon: Icons.work_outline_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 18),

                // ── Difficulty ─────────────────────────────
                _lbl(isAr ? 'مستوى الصعوبة' : 'Difficulty', isDark),
                const SizedBox(height: 8),
                _ThreeWay(
                  options: [
                    (
                      'beginner',
                      isAr ? 'مبتدئ' : 'Beginner',
                      AppColors.emerald,
                      Icons.school_outlined
                    ),
                    (
                      'intermediate',
                      isAr ? 'متوسط' : 'Intermediate',
                      AppColors.violet,
                      Icons.trending_up_rounded
                    ),
                    (
                      'advanced',
                      isAr ? 'متقدم' : 'Advanced',
                      AppColors.rose,
                      Icons.rocket_launch_outlined
                    ),
                  ],
                  selected: _difficulty,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _difficulty = v),
                ),
                const SizedBox(height: 18),

                // ── Path type ──────────────────────────────
                _lbl(isAr ? 'نوع المسار' : 'Path Type', isDark),
                const SizedBox(height: 8),
                _ThreeWay(
                  options: [
                    (
                      'certification',
                      isAr ? 'شهادات' : 'Certifications',
                      AppColors.amber,
                      Icons.verified_rounded
                    ),
                    (
                      'balanced',
                      isAr ? 'متوازن' : 'Balanced',
                      AppColors.violet,
                      Icons.balance_rounded
                    ),
                    (
                      'project',
                      isAr ? 'مشاريع' : 'Projects',
                      AppColors.cyan,
                      Icons.code_rounded
                    ),
                  ],
                  selected: _pathType,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _pathType = v),
                ),
                const SizedBox(height: 18),

                // ── Hours + Weeks ──────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl(isAr ? 'ساعات / أسبوع' : 'Hours / Week', isDark),
                          const SizedBox(height: 8),
                          _Steps(
                            value: _hoursPerWeek,
                            options: const [5, 10, 20, 40],
                            color: AppColors.violet,
                            isDark: isDark,
                            suffix: isAr ? 'س' : 'h',
                            onChanged: (v) => setState(() => _hoursPerWeek = v),
                          ),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl(isAr ? 'المدة (أسابيع)' : 'Duration (wks)',
                              isDark),
                          const SizedBox(height: 8),
                          _Steps(
                            value: _targetWeeks,
                            options: const [4, 8, 12, 16],
                            color: AppColors.emerald,
                            isDark: isDark,
                            suffix: isAr ? 'أ' : 'w',
                            onChanged: (v) => setState(() => _targetWeeks = v),
                          ),
                        ]),
                  ),
                ]),
                const SizedBox(height: 18),

                // ── Capstone toggle ────────────────────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _includeCapstone = !_includeCapstone);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _includeCapstone
                          ? AppColors.cyan.withValues(alpha: 0.08)
                          : (isDark ? const Color(0xFF1E222C) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _includeCapstone
                            ? AppColors.cyan.withValues(alpha: 0.40)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06)),
                        width: _includeCapstone ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: _includeCapstone
                                ? AppColors.cyan.withValues(alpha: 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.rocket_launch_rounded,
                            color:
                                _includeCapstone ? AppColors.cyan : Colors.grey,
                            size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'مشروع ختامي (Capstone)'
                                    : 'Capstone Project',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _includeCapstone
                                        ? AppColors.cyan
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1C20))),
                              ),
                              Text(
                                isAr
                                    ? 'مشروع نهائي يجمع كل ما تعلمته'
                                    : 'A final project applying everything',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.38)
                                        : Colors.black.withValues(alpha: 0.38)),
                              ),
                            ]),
                      ),
                      // Animated toggle switch
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 26,
                        decoration: BoxDecoration(
                            color: _includeCapstone
                                ? AppColors.cyan
                                : Colors.grey.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(13)),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _includeCapstone
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Resume (optional) ──────────────────────
                resumesAsync.when(
                  data: (resumes) => resumes.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              _lbl(
                                  isAr
                                      ? 'استند إلى سيرة ذاتية (اختياري)'
                                      : 'Base on Resume (Optional)',
                                  isDark),
                              const SizedBox(height: 8),
                              _ResumeDropdown(
                                resumes: resumes,
                                selected: _resumeId,
                                isDark: isDark,
                                isAr: isAr,
                                onChanged: (v) => setState(() => _resumeId = v),
                              ),
                              const SizedBox(height: 18),
                            ]),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Summary pill ───────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.violet.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppColors.violet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAr
                            ? 'مسار ${_pathLabel(true)} • ${_diffLabel(true)} • $_hoursPerWeek س/أسبوع • $_targetWeeks أسبوع${_includeCapstone ? " • مشروع ختامي ✓" : ""}'
                            : '${_pathLabel(false)} • ${_diffLabel(false)} • ${_hoursPerWeek}h/week • $_targetWeeks weeks${_includeCapstone ? " • Capstone ✓" : ""}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.violet.withValues(alpha: 0.80),
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Generate button ────────────────────────
                GestureDetector(
                  onTap: _isGenerating ? null : _generate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _isGenerating
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.violet, Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _isGenerating
                          ? AppColors.violet.withValues(alpha: 0.45)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _isGenerating
                          ? null
                          : [
                              BoxShadow(
                                  color:
                                      AppColors.violet.withValues(alpha: 0.40),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8)),
                            ],
                    ),
                    child: Center(
                      child: _isGenerating
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5)),
                              const SizedBox(width: 12),
                              Text(isAr ? 'جاري الإنشاء...' : 'Generating…',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ])
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                  isAr
                                      ? 'إنشاء خارطة الذكاء'
                                      : 'Generate AI Roadmap',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                            ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _lbl(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark
              ? Colors.white.withValues(alpha: 0.55)
              : Colors.black.withValues(alpha: 0.50)));
}

// ══════════════════════════════════════════════════════════════════
// THREE-WAY SELECTOR
// ══════════════════════════════════════════════════════════════════
class _ThreeWay extends StatelessWidget {
  final List<(String, String, Color, IconData)> options;
  final String selected;
  final bool isDark;
  final void Function(String) onChanged;
  const _ThreeWay(
      {required this.options,
      required this.selected,
      required this.isDark,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: options.map((opt) {
          final (value, label, color, icon) = opt;
          final isSel = selected == value;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onChanged(value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSel
                      ? color.withValues(alpha: 0.12)
                      : (isDark ? const Color(0xFF1E222C) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel
                        ? color
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    width: isSel ? 1.5 : 1,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Column(children: [
                  Icon(icon, size: 18, color: isSel ? color : Colors.grey),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          color: isSel ? color : Colors.grey,
                          fontSize: 11,
                          fontWeight:
                              isSel ? FontWeight.w800 : FontWeight.w500)),
                ]),
              ),
            ),
          );
        }).toList(),
      );
}

// ══════════════════════════════════════════════════════════════════
// STEP SELECTOR
// ══════════════════════════════════════════════════════════════════
class _Steps extends StatelessWidget {
  final int value;
  final List<int> options;
  final Color color;
  final bool isDark;
  final String suffix;
  final void Function(int) onChanged;
  const _Steps(
      {required this.value,
      required this.options,
      required this.color,
      required this.isDark,
      required this.suffix,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: options.map((opt) {
            final isSel = value == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(opt);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('$opt$suffix',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSel ? FontWeight.w900 : FontWeight.w500,
                            color: isSel ? Colors.white : Colors.grey)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// INPUT FIELD
// ══════════════════════════════════════════════════════════════════
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  const _InputField(
      {required this.controller,
      required this.hint,
      required this.icon,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: controller,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1C20)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.28)),
            prefixIcon: Icon(icon, color: AppColors.violet, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.violet, width: 1.5)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E222C) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// RESUME DROPDOWN
// ══════════════════════════════════════════════════════════════════
class _ResumeDropdown extends StatelessWidget {
  final List resumes;
  final int? selected;
  final bool isDark, isAr;
  final void Function(int?) onChanged;
  const _ResumeDropdown(
      {required this.resumes,
      required this.selected,
      required this.isDark,
      required this.isAr,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: selected,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E222C) : Colors.white,
            icon:
                const Icon(Icons.expand_more_rounded, color: AppColors.violet),
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1C20),
                fontSize: 14,
                fontWeight: FontWeight.w600),
            items: [
              DropdownMenuItem(
                value: null,
                child: Row(children: [
                  const Icon(Icons.description_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(isAr ? 'بدون سيرة ذاتية' : 'Without resume',
                      style: const TextStyle(color: Colors.grey)),
                ]),
              ),
              ...resumes.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Row(children: [
                      const Icon(Icons.description_rounded,
                          size: 16, color: AppColors.violet),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(r.title ?? 'Resume ${r.id}',
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}
