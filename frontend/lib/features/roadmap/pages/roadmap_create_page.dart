// lib/features/roadmap/pages/roadmap_create_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isAr ? 'أدخل الدور المستهدف' : 'Please enter a target role'),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);

    final success = await ref.read(roadmapListProvider.notifier).generate(
        targetRole: _roleCtrl.text.trim(),
        difficulty: _difficulty,
        resumeId: _resumeId);

    if (!mounted) return;
    setState(() => _isGenerating = false);

    if (success) {
      final roadmaps = ref.read(roadmapListProvider).roadmaps;
      if (roadmaps.isNotEmpty) {
        context.go('/roadmap/${roadmaps.last.id}');
      } else {
        context.go('/roadmap');
      }
    } else {
      final isArNow = Directionality.of(context) == TextDirection.rtl;
      final error = ref.read(roadmapListProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ??
              (isArNow ? 'فشل إنشاء الخارطة' : 'Failed to generate roadmap')),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

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
        // ── Header ──────────────────────────────────────────
        SizedBox(height: top + 12),
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
                  borderRadius: BorderRadius.circular(13),
                ),
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

        // ── Content ─────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(children: [
              // Hero card
              _HeroCard(isDark: isDark, isAr: isAr),
              const SizedBox(height: 20),

              // Role input
              _Section(
                label: isAr ? 'الدور المستهدف' : 'Target Role',
                isDark: isDark,
                child: _InputField(
                  controller: _roleCtrl,
                  hint: isAr ? 'مثال: مطور Flutter' : 'e.g. Flutter Developer',
                  icon: Icons.work_outline_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Difficulty
              _Section(
                label: isAr ? 'مستوى الصعوبة' : 'Difficulty Level',
                isDark: isDark,
                child: _DifficultySelector(
                  selected: _difficulty,
                  isDark: isDark,
                  isAr: isAr,
                  onChanged: (d) => setState(() => _difficulty = d),
                ),
              ),
              const SizedBox(height: 16),

              // Resume (optional)
              resumesAsync.when(
                data: (resumes) => resumes.isEmpty
                    ? const SizedBox.shrink()
                    : _Section(
                        label: isAr
                            ? 'استند إلى سيرة ذاتية (اختياري)'
                            : 'Base on Resume (Optional)',
                        isDark: isDark,
                        child: _ResumeDropdown(
                          resumes: resumes,
                          selected: _resumeId,
                          isDark: isDark,
                          isAr: isAr,
                          onChanged: (v) => setState(() => _resumeId = v),
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),

              // Generate button
              _GenerateButton(
                isAr: isAr,
                isGenerating: _isGenerating,
                onTap: _generate,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HERO CARD
// ══════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final bool isDark, isAr;
  const _HeroCard({required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    ? 'يحلل الذكاء ملفك ويبني خطة مخصصة لك'
                    : 'AI analyzes your profile and builds a personalized plan',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// SECTION WRAPPER
// ══════════════════════════════════════════════════════════════════
class _Section extends StatelessWidget {
  final String label;
  final bool isDark;
  final Widget child;
  const _Section(
      {required this.label, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.50))),
          const SizedBox(height: 8),
          child,
        ],
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
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
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
// DIFFICULTY SELECTOR
// ══════════════════════════════════════════════════════════════════
class _DifficultySelector extends StatelessWidget {
  final String selected;
  final bool isDark, isAr;
  final void Function(String) onChanged;
  const _DifficultySelector({
    required this.selected,
    required this.isDark,
    required this.isAr,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('beginner', isAr ? 'مبتدئ' : 'Beginner', AppColors.emerald),
      ('intermediate', isAr ? 'متوسط' : 'Intermediate', AppColors.violet),
      ('advanced', isAr ? 'متقدم' : 'Advanced', AppColors.rose),
    ];

    return Row(
      children: options.map((opt) {
        final (value, label, color) = opt;
        final isSelected = selected == value;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E222C) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Column(children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected ? color : Colors.grey,
                ),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: isSelected ? color : Colors.grey,
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// RESUME DROPDOWN
// ══════════════════════════════════════════════════════════════════
class _ResumeDropdown extends StatelessWidget {
  final List resumes;
  final int? selected;
  final bool isDark, isAr;
  final void Function(int?) onChanged;
  const _ResumeDropdown({
    required this.resumes,
    required this.selected,
    required this.isDark,
    required this.isAr,
    required this.onChanged,
  });

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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
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
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// GENERATE BUTTON
// ══════════════════════════════════════════════════════════════════
class _GenerateButton extends StatelessWidget {
  final bool isAr, isGenerating;
  final VoidCallback onTap;
  const _GenerateButton({
    required this.isAr,
    required this.isGenerating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isGenerating ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: isGenerating
                ? null
                : const LinearGradient(
                    colors: [AppColors.violet, Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color:
                isGenerating ? AppColors.violet.withValues(alpha: 0.45) : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isGenerating
                ? null
                : [
                    BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.40),
                        blurRadius: 18,
                        offset: const Offset(0, 8)),
                  ],
          ),
          child: Center(
            child: isGenerating
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isAr ? 'جاري الإنشاء...' : 'Generating…',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isAr ? 'إنشاء خارطة الذكاء' : 'Generate AI Roadmap',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                    ),
                  ]),
          ),
        ),
      );
}
