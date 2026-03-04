// lib/features/roadmap/pages/roadmap_create_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard, ModernTextField, PrimaryButton
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
    if (_roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a target role'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final success = await ref.read(roadmapListProvider.notifier).generate(
          targetRole: _roleCtrl.text.trim(),
          difficulty: _difficulty,
          resumeId: _resumeId,
        );

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error ?? 'Failed to generate roadmap'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumesAsync = ref.watch(resumesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          // FIX 1: const + relative import (package:frontend → shared/widgets)
          const BackgroundPainter(),
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassCard(
                  isDark: isDark,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 32),
                      ModernTextField(
                        controller: _roleCtrl,
                        label: 'Target Job Role',
                        hint: 'e.g. Senior Full Stack Developer',
                        icon: Icons.work_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _buildDifficultySelector(isDark),
                      const SizedBox(height: 24),
                      // FIX 2: branded loading indicator color
                      resumesAsync.when(
                        data: (resumes) => resumes.isEmpty
                            ? const SizedBox.shrink()
                            : _buildResumeDropdown(resumes, isDark),
                        loading: () => const LinearProgressIndicator(
                            color: AppColors.violet),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 40),
                      PrimaryButton(
                        label: 'Generate AI Roadmap',
                        isLoading: _isGenerating,
                        onTap: _generate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.violet, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Learning Path',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('AI will analyze your profile to build milestones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13)),
        ],
      );

  Widget _buildDifficultySelector(bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Difficulty Level',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: ['beginner', 'intermediate', 'advanced'].map((d) {
              final isSelected = _difficulty == d;
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
                              : Colors.transparent),
                    ),
                    child: Center(
                      child: Text(d[0].toUpperCase() + d.substring(1),
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildResumeDropdown(List resumes, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Base on Resume (Optional)',
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _resumeId,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                // FIX 3: explicit text style so items are visible in both modes
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Standard (No Resume)',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87)),
                  ),
                  ...resumes.map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.title ?? 'Resume ${r.id}',
                            style: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black87)),
                      )),
                ],
                onChanged: (val) => setState(() => _resumeId = val),
              ),
            ),
          ),
        ],
      );
}
