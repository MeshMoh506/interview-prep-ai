// lib/features/interview/pages/interview_setup_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/interview_provider.dart';
import '../../resume/providers/resume_provider.dart';
import '../services/interview_service.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../widgets/avatar_selector.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard, ModernTextField, PrimaryButton

// Provider for available roles
final availableRolesProvider = FutureProvider<List<String>>((ref) async {
  final service = InterviewService();
  final result = await service.getAvailableRoles();
  if (result['success']) {
    return result['roles'] as List<String>;
  }
  return [
    'Software Engineer',
    'Frontend Developer',
    'Backend Developer',
    'Full Stack Developer',
    'Mobile Developer',
    'Data Scientist',
    'Product Manager',
    'DevOps Engineer',
  ];
});

class InterviewSetupPage extends ConsumerStatefulWidget {
  const InterviewSetupPage({super.key});

  @override
  ConsumerState<InterviewSetupPage> createState() => _InterviewSetupPageState();
}

class _InterviewSetupPageState extends ConsumerState<InterviewSetupPage> {
  final _roleCtrl = TextEditingController(text: 'Software Engineer');
  String _difficulty = 'medium';
  final String _interviewType = 'mixed';
  String _language = 'en';
  int? _selectedResumeId;
  bool _useAvatar = false;
  String _selectedAvatarId = 'professional_female';
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(resumeProvider.notifier).loadResumes();
    });
  }

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final role = _roleCtrl.text.trim();
    if (role.isEmpty) {
      _snack('Enter a job role', isError: true);
      return;
    }
    setState(() => _starting = true);

    ref.read(interviewSessionProvider.notifier).reset();

    final ok = await ref.read(interviewSessionProvider.notifier).startInterview(
          jobRole: role,
          difficulty: _difficulty,
          interviewType: _interviewType,
          language: _language,
          resumeId: _selectedResumeId,
          useAvatar: _useAvatar,
          avatarId: _selectedAvatarId,
        );

    if (!mounted) return;
    setState(() => _starting = false);

    if (ok) {
      context.go('/interview/chat');
    } else {
      _snack(
        ref.read(interviewSessionProvider).error ?? 'Failed to start',
        isError: true,
      );
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.rose : AppColors.emerald,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final resumeState = ref.watch(resumeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          // FIX 1: const + relative import
          const BackgroundPainter(),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                        // FIX 2: withOpacity → withValues (×2)
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/interview'),
                ),
                title: const Text('Setup Session',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                actions: [
                  const ThemeToggleButton(),
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () => context.push('/interview/history'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: GlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroIcon(isDark),
                            const SizedBox(height: 24),

                            // Job Role
                            ModernTextField(
                              controller: _roleCtrl,
                              label: 'Target Job Role',
                              hint: 'e.g. Software Engineer',
                              icon: Icons.work_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20),

                            // Resume Selection
                            if (resumeState.resumes.isNotEmpty) ...[
                              _label('Base on Resume', isDark),
                              _buildDropdown(resumeState.resumes, isDark),
                              const SizedBox(height: 20),
                            ],

                            // Difficulty
                            _label('Difficulty Level', isDark),
                            _buildDifficultyRow(isDark),
                            const SizedBox(height: 20),

                            // Language
                            _label('Interview Language', isDark),
                            _buildLanguageRow(isDark),
                            const SizedBox(height: 20),

                            // AI Avatar Toggle
                            _buildAvatarToggle(isDark),

                            const SizedBox(height: 32),
                            PrimaryButton(
                              label: _useAvatar
                                  ? 'Start Avatar Session'
                                  : 'Start Voice Interview',
                              isLoading: _starting,
                              onTap: _start,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FIX 3: hero icon uses withValues
  Widget _buildHeroIcon(bool isDark) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              // FIX 3: withOpacity → withValues
              color: AppColors.violet.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.psychology_rounded,
              color: AppColors.violet, size: 40),
        ),
      );

  Widget _label(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1.2)),
      );

  Widget _buildDropdown(List resumes, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            // FIX 4: withOpacity → withValues
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _selectedResumeId,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            // FIX 5: explicit style so text is visible in dark mode
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 14),
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
                            color: isDark ? Colors.white70 : Colors.black87)),
                  )),
            ],
            onChanged: (val) => setState(() => _selectedResumeId = val),
          ),
        ),
      );

  Widget _buildDifficultyRow(bool isDark) => Row(
        children: ['easy', 'medium', 'hard'].map((d) {
          final sel = _difficulty == d;
          final color = d == 'easy'
              ? AppColors.emerald
              : (d == 'medium' ? AppColors.amber : AppColors.rose);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _difficulty = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  // FIX 6: withOpacity → withValues
                  color: sel
                      ? color.withValues(alpha: 0.2)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? color : Colors.transparent),
                ),
                child: Center(
                    child: Text(d.toUpperCase(),
                        style: TextStyle(
                            color: sel ? color : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w900))),
              ),
            ),
          );
        }).toList(),
      );

  Widget _buildLanguageRow(bool isDark) => Row(
        children: [
          _langChip('🇺🇸 EN', 'en', isDark),
          const SizedBox(width: 12),
          _langChip('🇸🇦 AR', 'ar', isDark),
        ],
      );

  Widget _langChip(String label, String code, bool isDark) {
    final sel = _language == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _language = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            // FIX 7: withOpacity → withValues
            color: sel
                ? AppColors.cyan.withValues(alpha: 0.2)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: sel ? AppColors.cyan : Colors.transparent),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? AppColors.cyan : Colors.grey,
                      fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildAvatarToggle(bool isDark) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            // FIX 8: withOpacity → withValues
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Enable AI Avatar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Visual talking interviewer',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              value: _useAvatar,
              // FIX 9: activeColor → activeThumbColor (deprecated fix)
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.violet,
              onChanged: (v) => setState(() => _useAvatar = v),
            ),
            if (_useAvatar)
              Padding(
                padding: const EdgeInsets.all(12),
                child: AvatarSelector(
                  selectedAvatarId: _selectedAvatarId,
                  onAvatarSelected: (id) =>
                      setState(() => _selectedAvatarId = id),
                ),
              ),
          ],
        ),
      );
}
