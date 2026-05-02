// lib/features/interview/pages/interview_setup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/interview_provider.dart';
import '../services/interview_service.dart';
import '../../resume/providers/resume_provider.dart';
import '../../goals/providers/goal_provider.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../widgets/anam_avatar_picker.dart';
import '../../../shared/widgets/transitions.dart';

class InterviewSetupPage extends ConsumerStatefulWidget {
  const InterviewSetupPage({super.key});
  @override
  ConsumerState<InterviewSetupPage> createState() => _SetupState();
}

class _SetupState extends ConsumerState<InterviewSetupPage> {
  final _roleCtrl = TextEditingController(text: 'Software Engineer');
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _interviewService = InterviewService();

  String _difficulty = 'medium';
  String _language = 'en';
  int? _resumeId;
  int? _goalId;
  InterviewMode _mode = InterviewMode.textVoice;
  bool _starting = false;
  bool _goalPrefilled = false;

  // ── Anam avatar state ────────────────────────────────────────
  String _anamAvatarId = 'english_male';
  List<Map<String, dynamic>> _anamAvatars = [];
  bool _loadingAvatars = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(resumeProvider.notifier).loadResumes();
      _loadAnamAvatars();
    });
  }

  Future<void> _loadAnamAvatars() async {
    setState(() => _loadingAvatars = true);
    try {
      final avatars = await _interviewService.getAnamAvatars();
      if (mounted) {
        setState(() {
          _anamAvatars = avatars;
          final match =
              avatars.where((a) => a['language'] == _language).toList();
          if (match.isNotEmpty) _anamAvatarId = match.first['id'] as String;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAvatars = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyGoalExtra();
  }

  void _applyGoalExtra() {
    if (_goalPrefilled) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      final goalId = extra['goalId'] as int?;
      final role = extra['role'] as String?;
      final diff = extra['difficulty'] as String?;
      final lang = extra['language'] as String?;
      final resumeId = extra['resumeId'] as int?;
      if (goalId != null) {
        setState(() {
          _goalId = goalId;
          _goalPrefilled = true;
          if (role?.isNotEmpty == true) _roleCtrl.text = role!;
          if (diff != null) _difficulty = diff;
          if (lang != null) _language = lang;
          if (resumeId != null) _resumeId = resumeId;
        });
      }
    }
  }

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final role = _roleCtrl.text.trim();
    if (role.isEmpty) {
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return;
    }
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();

    if (_mode == InterviewMode.video) {
      await _startAnamInterview(role);
    } else {
      await _startTextVoiceInterview(role);
    }
  }

  Future<void> _startAnamInterview(String role) async {
    try {
      final result = await _interviewService.startAnamInterview(
        jobRole: role,
        difficulty: _difficulty,
        interviewType: 'mixed',
        language: _language,
        avatarId: _anamAvatarId,
        goalId: _goalId,
        resumeId: _resumeId,
      );
      if (!mounted) return;
      setState(() => _starting = false);

      if (result['success'] == true) {
        context.push('/interview/anam', extra: {
          'interview_id': result['interview_id'] as int,
          'session_token': result['session_token'] as String,
          'avatar_name': result['avatar_name'] as String? ?? 'AI Interviewer',
          'job_role': role,
          'language': _language,
        });
      } else {
        _showError(
            result['message'] as String? ?? 'Failed to start video interview');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        _showError(e.toString());
      }
    }
  }

  Future<void> _startTextVoiceInterview(String role) async {
    final s = AppStrings.of(context);
    ref.read(interviewSessionProvider.notifier).reset();
    final ok = await ref.read(interviewSessionProvider.notifier).startInterview(
          jobRole: role,
          difficulty: _difficulty,
          interviewType: 'mixed',
          language: _language,
          resumeId: _resumeId,
          goalId: _goalId,
          mode: InterviewMode.textVoice,
          useAvatar: false,
        );
    if (!mounted) return;
    setState(() => _starting = false);
    if (ok) {
      context.go('/interview/chat');
    } else {
      _showError(ref.read(interviewSessionProvider).error ?? s.errStartFailed);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final resumeState = ref.watch(resumeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final s = AppStrings.of(context);
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);

    String? goalRole;
    if (_goalId != null) {
      final gs = ref.watch(goalProvider);
      goalRole =
          gs.goals.where((g) => g.id == _goalId).firstOrNull?.targetRole ??
              _roleCtrl.text;
    }

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Column(children: [
        _SetupHeader(
            isDark: isDark,
            isAr: isAr,
            s: s,
            onBack: () =>
                _goalId != null ? context.pop() : context.go('/interview'),
            onHistory: () => context.push('/interview/history')),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(children: [
              // Goal banner
              if (_goalId != null && goalRole != null) ...[
                _GoalBanner(
                    role: goalRole,
                    isDark: isDark,
                    isAr: isAr,
                    onClear: () => setState(() {
                          _goalId = null;
                          _goalPrefilled = false;
                        })),
                const SizedBox(height: 16),
              ],

              // Mode
              _Section(
                  label: s.interviewMode,
                  isDark: isDark,
                  child: Row(children: [
                    Expanded(
                        child: _ModeCard(
                            isDark: isDark,
                            selected: _mode == InterviewMode.textVoice,
                            icon: Icons.chat_bubble_rounded,
                            color: AppColors.violet,
                            title: s.interviewTextVoice,
                            badge: null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _mode = InterviewMode.textVoice);
                            })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ModeCard(
                            isDark: isDark,
                            selected: _mode == InterviewMode.video,
                            icon: Icons.videocam_rounded,
                            color: AppColors.rose,
                            title: s.interviewLiveVideo,
                            badge: 'LIVE',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _mode = InterviewMode.video);
                            })),
                  ])),
              _ModeHint(mode: _mode, isAr: isAr),
              const SizedBox(height: 16),

              // Job role
              _Section(
                  label: s.interviewTargetRole,
                  isDark: isDark,
                  child: _RoleField(
                      ctrl: _roleCtrl,
                      isDark: isDark,
                      hint: s.interviewRoleHint)),
              const SizedBox(height: 16),

              // Difficulty
              _Section(
                  label: s.interviewDifficulty,
                  isDark: isDark,
                  child: _DiffRow(
                      selected: _difficulty,
                      isAr: isAr,
                      isDark: isDark,
                      onSelect: (d) => setState(() => _difficulty = d))),
              const SizedBox(height: 16),

              // Resume
              if (resumeState.resumes.isNotEmpty) ...[
                _Section(
                    label: s.interviewBaseResume,
                    isDark: isDark,
                    child: _ResumeDrop(
                        resumes: resumeState.resumes,
                        value: _resumeId,
                        isDark: isDark,
                        s: s,
                        onChanged: (v) => setState(() => _resumeId = v))),
                const SizedBox(height: 16),
              ],

              // Language
              _Section(
                  label: s.interviewLanguage,
                  isDark: isDark,
                  child: _LangRow(
                      selected: _language,
                      isDark: isDark,
                      onSelect: (l) {
                        setState(() {
                          _language = l;
                          // Auto-select avatar matching new language
                          final match = _anamAvatars
                              .where((a) => a['language'] == l)
                              .toList();
                          if (match.isNotEmpty) {
                            _anamAvatarId = match.first['id'] as String;
                          }
                        });
                      })),
              const SizedBox(height: 16),

              // Avatar picker — video mode only
              if (_mode == InterviewMode.video) ...[
                _Section(
                    label: isAr ? 'المُقابِل' : 'AI Interviewer',
                    isDark: isDark,
                    child: _loadingAvatars
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: AppColors.violet, strokeWidth: 2)))
                        : _anamAvatars.isEmpty
                            ? _AvatarLoadError(
                                isAr: isAr,
                                isDark: isDark,
                                onRetry: _loadAnamAvatars)
                            : AnamAvatarPicker(
                                avatars: _anamAvatars,
                                language: _language,
                                onSelected: (id) =>
                                    setState(() => _anamAvatarId = id))),
                const SizedBox(height: 16),
              ],

              // Start button
              ShakeWidget(
                  key: _shakeKey,
                  child: _StartBtn(
                      isLoading: _starting,
                      onTap: _start,
                      isDark: isDark,
                      label: _mode == InterviewMode.video
                          ? (isAr
                              ? 'بدء مقابلة بالفيديو'
                              : 'Start Video Interview')
                          : s.interviewStart)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══ Avatar load error ════════════════════════════════════════════
class _AvatarLoadError extends StatelessWidget {
  final bool isAr, isDark;
  final VoidCallback onRetry;
  const _AvatarLoadError(
      {required this.isAr, required this.isDark, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? 'تعذّر تحميل المحاورين' : 'Could not load interviewers',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black45)),
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.violet),
              label: Text(isAr ? 'إعادة' : 'Retry',
                  style:
                      const TextStyle(color: AppColors.violet, fontSize: 13))),
        ]),
      );
}

// ══ Header ═══════════════════════════════════════════════════════
class _SetupHeader extends StatelessWidget {
  final bool isDark, isAr;
  final AppStrings s;
  final VoidCallback onBack, onHistory;
  const _SetupHeader(
      {required this.isDark,
      required this.isAr,
      required this.s,
      required this.onBack,
      required this.onHistory});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9),
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 8),
      child: Row(children: [
        GestureDetector(
            onTap: onBack,
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(
                    isAr
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : Colors.black.withValues(alpha: 0.70),
                    size: 24))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(s.interviewSetup,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20)))),
        GestureDetector(
            onTap: onHistory,
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.history_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : Colors.black.withValues(alpha: 0.60),
                    size: 20))),
      ]),
    );
  }
}

// ══ Section ══════════════════════════════════════════════════════
class _Section extends StatelessWidget {
  final String label;
  final bool isDark;
  final Widget child;
  const _Section(
      {required this.label, required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.38)
                        : Colors.black.withValues(alpha: 0.38)))),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222C) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]),
            child: child),
      ]);
}

// ══ Mode card ════════════════════════════════════════════════════
class _ModeCard extends StatelessWidget {
  final bool isDark, selected;
  final IconData icon;
  final Color color;
  final String title;
  final String? badge;
  final VoidCallback onTap;
  const _ModeCard(
      {required this.isDark,
      required this.selected,
      required this.icon,
      required this.color,
      required this.title,
      this.badge,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? color : Colors.transparent, width: 2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : null),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.topRight, children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? 0.20 : 0.10),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 26)),
              if (badge != null)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected
                        ? color
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : Colors.black.withValues(alpha: 0.55)))),
            const SizedBox(height: 8),
            AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : Colors.transparent,
                    border: Border.all(
                        color: selected ? color : Colors.grey.shade400,
                        width: 2)),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 11, color: Colors.white)
                    : null),
          ])));
}

// ══ Mode hint ════════════════════════════════════════════════════
class _ModeHint extends StatelessWidget {
  final InterviewMode mode;
  final bool isAr;
  const _ModeHint({required this.mode, required this.isAr});
  @override
  Widget build(BuildContext context) {
    final isVideo = mode == InterviewMode.video;
    final color = isVideo ? AppColors.rose : AppColors.violet;
    final text = isVideo
        ? (isAr
            ? 'مقابلة فيديو حية مع أفاتار ذكاء اصطناعي — تحدّث مباشرةً مع المحاور.'
            : 'Live AI avatar interview — speak directly to your interviewer in real-time.')
        : (isAr
            ? 'اكتب أو اضغط على المايكروفون لتسجيل إجاباتك.'
            : 'Type or hold the mic button to record your answers.');
    return AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18))),
        child: Row(children: [
          Icon(
              isVideo
                  ? Icons.videocam_rounded
                  : Icons.lightbulb_outline_rounded,
              size: 15,
              color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, height: 1.4, color: color))),
        ]));
  }
}

// ══ Role field ═══════════════════════════════════════════════════
class _RoleField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final String hint;
  const _RoleField(
      {required this.ctrl, required this.isDark, required this.hint});
  @override
  Widget build(BuildContext context) => TextField(
      controller: ctrl,
      style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF1A1C20)),
      decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.28)),
          prefixIcon:
              const Icon(Icons.work_rounded, color: AppColors.violet, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 4)));
}

// ══ Difficulty ═══════════════════════════════════════════════════
class _DiffRow extends StatelessWidget {
  final String selected;
  final bool isAr, isDark;
  final ValueChanged<String> onSelect;
  const _DiffRow(
      {required this.selected,
      required this.isAr,
      required this.isDark,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final items = [
      ('easy', isAr ? 'سهل' : 'Easy', AppColors.emerald),
      ('medium', isAr ? 'متوسط' : 'Medium', AppColors.amber),
      ('hard', isAr ? 'صعب' : 'Hard', AppColors.rose)
    ];
    return Row(
        children: items.map((item) {
      final (k, label, color) = item;
      final sel = selected == k;
      return Expanded(
          child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(k);
              },
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: sel
                          ? color.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? color : Colors.transparent, width: 1.5)),
                  child: Center(
                      child: Text(label.toUpperCase(),
                          style: TextStyle(
                              color: sel ? color : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w900))))));
    }).toList());
  }
}

// ══ Resume dropdown ══════════════════════════════════════════════
class _ResumeDrop extends StatelessWidget {
  final List resumes;
  final int? value;
  final bool isDark;
  final AppStrings s;
  final ValueChanged<int?> onChanged;
  const _ResumeDrop(
      {required this.resumes,
      required this.value,
      required this.isDark,
      required this.s,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E222C) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.40)
                  : Colors.black.withValues(alpha: 0.35)),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1C20)),
          items: [
            DropdownMenuItem(
                value: null,
                child: Text(s.interviewNoResume,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.50)
                            : Colors.black.withValues(alpha: 0.40)))),
            ...resumes.map((r) => DropdownMenuItem(
                value: r.id, child: Text(r.title ?? 'Resume ${r.id}'))),
          ],
          onChanged: onChanged));
}

// ══ Language row ═════════════════════════════════════════════════
class _LangRow extends StatelessWidget {
  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelect;
  const _LangRow(
      {required this.selected, required this.isDark, required this.onSelect});
  @override
  Widget build(BuildContext context) => Row(children: [
        _LangChip(
            label: '🇺🇸 English',
            code: 'en',
            selected: selected == 'en',
            isDark: isDark,
            onTap: () => onSelect('en')),
        const SizedBox(width: 12),
        _LangChip(
            label: '🇸🇦 العربية',
            code: 'ar',
            selected: selected == 'ar',
            isDark: isDark,
            onTap: () => onSelect('ar')),
      ]);
}

class _LangChip extends StatelessWidget {
  final String label, code;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _LangChip(
      {required this.label,
      required this.code,
      required this.selected,
      required this.isDark,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
      child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: selected
                      ? AppColors.cyan.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? AppColors.cyan : Colors.transparent,
                      width: 1.5)),
              child: Center(
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? AppColors.cyan : Colors.grey,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))))));
}

// ══ Goal banner ══════════════════════════════════════════════════
class _GoalBanner extends StatelessWidget {
  final String role;
  final bool isDark, isAr;
  final VoidCallback onClear;
  const _GoalBanner(
      {required this.role,
      required this.isDark,
      required this.isAr,
      required this.onClear});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.25))),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.violet, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((isAr ? 'مقابلة ضمن هدف' : 'GOAL INTERVIEW').toUpperCase(),
              style: const TextStyle(
                  color: AppColors.violet,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8)),
          Text(role,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded,
                size: 18,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.25))),
      ]));
}

// ══ Start button ═════════════════════════════════════════════════
class _StartBtn extends StatelessWidget {
  final bool isLoading, isDark;
  final String label;
  final VoidCallback onTap;
  const _StartBtn(
      {required this.isLoading,
      required this.isDark,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.40),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]),
          child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)))));
}
