// lib/features/interview/pages/interview_setup_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/interview_provider.dart';
import '../../resume/providers/resume_provider.dart';
import '../services/interview_service.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../widgets/avatar_picker.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/transitions.dart';

const String _kApiBase = 'http://localhost:8000';

final availableRolesProvider = FutureProvider<List<String>>((ref) async {
  final roles = await InterviewService().getAvailableRoles();
  if (roles.isNotEmpty) return roles;
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
  ConsumerState<InterviewSetupPage> createState() => _SetupState();
}

class _SetupState extends ConsumerState<InterviewSetupPage> {
  final _roleCtrl = TextEditingController(text: 'Software Engineer');
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  String _difficulty = 'medium';
  String _language = 'en';
  int? _resumeId;
  String _avatarId = 'professional_female';
  String _avatarSourceUrl =
      '$_kApiBase/api/v1/avatars/photo/professional_female';
  String _avatarIdleVideoUrl = '';
  InterviewMode _mode = InterviewMode.textVoice;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resumeProvider.notifier).loadResumes());
  }

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final s = AppStrings.of(context);
    final role = _roleCtrl.text.trim();
    if (role.isEmpty) {
      _shakeKey.currentState?.shake();
      _snack(s.errEnterRole);
      return;
    }
    setState(() => _starting = true);
    ref.read(interviewSessionProvider.notifier).reset();

    final ok = await ref.read(interviewSessionProvider.notifier).startInterview(
          jobRole: role,
          difficulty: _difficulty,
          interviewType: 'mixed',
          language: _language,
          resumeId: _resumeId,
          avatarId: _avatarId,
          avatarSourceUrl: _avatarSourceUrl,
          avatarIdleVideoUrl: _avatarIdleVideoUrl,
          mode: _mode,
          useAvatar: _mode == InterviewMode.video,
        );

    if (!mounted) return;
    setState(() => _starting = false);

    if (ok) {
      context.go(_mode == InterviewMode.video
          ? '/interview/video'
          : '/interview/chat');
    } else {
      _snack(ref.read(interviewSessionProvider).error ??
          AppStrings.of(context).errStartFailed);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    final resumeState = ref.watch(resumeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(children: [
        const BackgroundPainter(),
        CustomScrollView(slivers: [
          // ── App bar ────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.go('/interview')),
            title: Text(s.interviewSetup,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            actions: [
              const ThemeToggleButton(),
              IconButton(
                  icon: const Icon(Icons.history_rounded),
                  onPressed: () => context.push('/interview/history')),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(children: [
                    // ── MODE SELECTOR ────────────────────────────
                    GlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(s.interviewMode, isDark),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: TapScale(
                                onTap: () => setState(
                                    () => _mode = InterviewMode.textVoice),
                                child: _ModeCard(
                                  isDark: isDark,
                                  selected: _mode == InterviewMode.textVoice,
                                  icon: Icons.chat_bubble_rounded,
                                  iconColor: AppColors.violet,
                                  title: s.interviewTextVoice,
                                  subtitle: s.interviewTextVoice,
                                  badge: null,
                                  onTap: () => setState(
                                      () => _mode = InterviewMode.textVoice),
                                ),
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TapScale(
                                onTap: () =>
                                    setState(() => _mode = InterviewMode.video),
                                child: _ModeCard(
                                  isDark: isDark,
                                  selected: _mode == InterviewMode.video,
                                  icon: Icons.videocam_rounded,
                                  iconColor: AppColors.rose,
                                  title: s.interviewLiveVideo,
                                  subtitle: s.interviewLiveVideo,
                                  badge: 'LIVE',
                                  onTap: () => setState(
                                      () => _mode = InterviewMode.video),
                                ),
                              )),
                            ]),
                            const SizedBox(height: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: _mode == InterviewMode.video
                                      ? AppColors.rose.withValues(alpha: 0.08)
                                      : AppColors.violet
                                          .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Icon(
                                    _mode == InterviewMode.video
                                        ? Icons.info_outline_rounded
                                        : Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: _mode == InterviewMode.video
                                        ? AppColors.rose
                                        : AppColors.violet),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        _mode == InterviewMode.video
                                            ? (Directionality.of(context) ==
                                                    TextDirection.rtl
                                                ? 'كاميراك ستبدأ فوراً. صوت فقط — الكتابة معطلة.'
                                                : 'Your camera starts immediately. Voice-only — typing is disabled.')
                                            : (Directionality.of(context) ==
                                                    TextDirection.rtl
                                                ? 'اكتب أو اضغط على زر المايكروفون لتسجيل إجاباتك.'
                                                : 'Type or hold the mic button to record your voice answers.'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: _mode == InterviewMode.video
                                                ? AppColors.rose
                                                : AppColors.violet))),
                              ]),
                            ),
                          ],
                        )),
                    const SizedBox(height: 16),

                    // ── JOB + SETTINGS ───────────────────────────
                    GlassCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroIcon(),
                            const SizedBox(height: 20),
                            ModernTextField(
                                controller: _roleCtrl,
                                label: s.interviewTargetRole,
                                hint: s.interviewRoleHint,
                                icon: Icons.work_rounded,
                                isDark: isDark),
                            const SizedBox(height: 20),
                            if (resumeState.resumes.isNotEmpty) ...[
                              _label(s.interviewBaseResume, isDark),
                              _resumeDropdown(resumeState.resumes, isDark, s),
                              const SizedBox(height: 20),
                            ],
                            _label(s.interviewDifficulty, isDark),
                            _diffRow(isDark),
                            const SizedBox(height: 20),
                            _label(s.interviewLanguage, isDark),
                            _langRow(isDark),
                            if (_mode == InterviewMode.video) ...[
                              const SizedBox(height: 24),
                              AvatarPicker(
                                selectedId: _avatarId,
                                onSelected: (AvatarOption avatar) {
                                  setState(() {
                                    _avatarId = avatar.id;
                                    _avatarSourceUrl = avatar.sourceUrl;
                                    _avatarIdleVideoUrl =
                                        avatar.idleVideoUrl ?? '';
                                  });
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Row(children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppColors.violet, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text('${avatar.name} selected',
                                              style: const TextStyle(
                                                  color: Colors.white))),
                                    ]),
                                    backgroundColor: const Color(0xFF1E293B),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                },
                              ),
                            ],
                            const SizedBox(height: 28),
                            ShakeWidget(
                              key: _shakeKey,
                              child: PrimaryButton(
                                  label: _mode == InterviewMode.video
                                      ? s.interviewStartVideo
                                      : s.interviewStart,
                                  isLoading: _starting,
                                  onTap: _start),
                            ),
                          ],
                        )),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _label(String text, bool isDark) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
              color: isDark ? Colors.white38 : Colors.black38)));

  Widget _buildHeroIcon() => Center(
      child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.psychology_rounded,
              color: AppColors.violet, size: 40)));

  Widget _resumeDropdown(List resumes, bool isDark, AppStrings s) => Container(
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
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(s.interviewNoResume,
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87))),
                ...resumes.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.title ?? 'Resume ${r.id}',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87)))),
              ],
              onChanged: (val) => setState(() => _resumeId = val))));

  Widget _diffRow(bool isDark) {
    final s = AppStrings.of(context);
    final labels = {
      'easy': Directionality.of(context) == TextDirection.rtl ? 'سهل' : 'Easy',
      'medium':
          Directionality.of(context) == TextDirection.rtl ? 'متوسط' : 'Medium',
      'hard': Directionality.of(context) == TextDirection.rtl ? 'صعب' : 'Hard',
    };
    return Row(
        children: ['easy', 'medium', 'hard'].map((d) {
      final sel = _difficulty == d;
      final color = d == 'easy'
          ? AppColors.emerald
          : (d == 'medium' ? AppColors.amber : AppColors.rose);
      return Expanded(
          child: TapScale(
              onTap: () => setState(() => _difficulty = d),
              child: GestureDetector(
                  onTap: () => setState(() => _difficulty = d),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: sel
                              ? color.withValues(alpha: 0.2)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? color : Colors.transparent)),
                      child: Center(
                          child: Text((labels[d] ?? d).toUpperCase(),
                              style: TextStyle(
                                  color: sel ? color : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)))))));
    }).toList());
  }

  Widget _langRow(bool isDark) => Row(children: [
        _langChip('🇺🇸 English', 'en', isDark),
        const SizedBox(width: 12),
        _langChip('🇸🇦 العربية', 'ar', isDark),
      ]);

  Widget _langChip(String label, String code, bool isDark) {
    final sel = _language == code;
    return Expanded(
        child: TapScale(
            onTap: () => setState(() => _language = code),
            child: GestureDetector(
                onTap: () => setState(() => _language = code),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: sel
                            ? AppColors.cyan.withValues(alpha: 0.2)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? AppColors.cyan : Colors.transparent)),
                    child: Center(
                        child: Text(label,
                            style: TextStyle(
                                color: sel ? AppColors.cyan : Colors.grey,
                                fontWeight: FontWeight.bold)))))));
  }
}

class _ModeCard extends StatelessWidget {
  final bool isDark, selected;
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.isDark,
    required this.selected,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: selected
                  ? iconColor.withValues(alpha: 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? iconColor : Colors.transparent, width: 2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: iconColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : null),
          child: Column(children: [
            Stack(alignment: Alignment.topRight, children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: selected ? 0.2 : 0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 24)),
              if (badge != null)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(8)),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: selected
                        ? iconColor
                        : (isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 8),
            AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? iconColor : Colors.transparent,
                    border: Border.all(
                        color: selected ? iconColor : Colors.grey.shade400,
                        width: 2)),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null),
          ]),
        ),
      );
}
