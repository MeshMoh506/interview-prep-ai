// lib/features/roadmap/pages/roadmap_create_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../auth/screens/login_screen.dart';
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
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    if (_roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isAr ? 'أدخل الدور المستهدف' : 'Please enter a target role'),
          behavior: SnackBarBehavior.floating));
      return;
    }

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
      final error = ref.read(roadmapListProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ??
              (isAr ? 'فشل إنشاء الخارطة' : 'Failed to generate roadmap')),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumesAsync = ref.watch(resumesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
        // Removed extendBody for better centering calculation
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 70,
          leading: Center(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : Colors.black87, size: 18),
              ),
            ),
          ),
          actions: const [SizedBox(width: 20)],
        ),
        body: Stack(children: [
          const BackgroundPainter(),
          Center(
            // Centering the card container
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassCard(
                  isDark: isDark,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(isDark, s, isAr),
                      const SizedBox(height: 32),
                      ModernTextField(
                          controller: _roleCtrl,
                          label: isAr
                              ? 'الدور الوظيفي المستهدف'
                              : 'Target Job Role',
                          hint: isAr
                              ? 'مثال: مطور Full Stack متقدم'
                              : 'e.g. Senior Full Stack Developer',
                          icon: Icons.work_outline_rounded,
                          isDark: isDark),
                      const SizedBox(height: 24),
                      _buildDifficultySelector(isDark, s, isAr),
                      const SizedBox(height: 24),
                      resumesAsync.when(
                          data: (resumes) => resumes.isEmpty
                              ? const SizedBox.shrink()
                              : _buildResumeDropdown(resumes, isDark, s, isAr),
                          loading: () => const LinearProgressIndicator(
                              color: AppColors.violet),
                          error: (_, __) => const SizedBox.shrink()),
                      const SizedBox(height: 40),
                      PrimaryButton(
                          label: isAr
                              ? 'إنشاء خارطة الذكاء الاصطناعي'
                              : 'Generate AI Roadmap',
                          isLoading: _isGenerating,
                          onTap: _generate),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]));
  }

  Widget _buildHeader(bool isDark, AppStrings s, bool isAr) =>
      Column(children: [
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.violet, size: 32)),
        const SizedBox(height: 16),
        Text(isAr ? 'مسار التعلم' : 'Learning Path',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text(
            isAr
                ? 'سيحلل الذكاء ملفك الشخصي لبناء معالم تعلّم.'
                : 'AI will analyze your profile to build milestones.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38, fontSize: 13)),
      ]);

  Widget _buildDifficultySelector(bool isDark, AppStrings s, bool isAr) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? 'مستوى الصعوبة' : 'Difficulty Level',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Row(
            children: ['beginner', 'intermediate', 'advanced'].map((d) {
          final isSelected = _difficulty == d;
          final label = isAr
              ? {
                  'beginner': 'مبتدئ',
                  'intermediate': 'متوسط',
                  'advanced': 'متقدم'
                }[d]!
              : d[0].toUpperCase() + d.substring(1);
          return Expanded(
              child: GestureDetector(
                  onTap: () => setState(() => _difficulty = d),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.violet
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected
                                  ? AppColors.violet
                                  : Colors.transparent)),
                      child: Center(
                          child: Text(label,
                              style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))))));
        }).toList()),
      ]);

  Widget _buildResumeDropdown(
          List resumes, bool isDark, AppStrings s, bool isAr) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            isAr
                ? 'بناءً على السيرة الذاتية (اختياري)'
                : 'Base on Resume (Optional)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                    value: _resumeId,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(
                              isAr
                                  ? 'قياسي (بدون سيرة)'
                                  : 'Standard (No Resume)',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87))),
                      ...resumes.map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.title ?? 'Resume ${r.id}',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87)))),
                    ],
                    onChanged: (val) => setState(() => _resumeId = val)))),
      ]);
}
