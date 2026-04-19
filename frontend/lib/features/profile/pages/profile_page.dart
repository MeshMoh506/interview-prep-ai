// lib/features/profile/pages/profile_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lang_toggle_button.dart';
import '../../../shared/widgets/achievements_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goal_provider.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Uint8List? _avatarBytes;
  bool _editMode = false; // toggle between view and edit

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final r = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: kIsWeb);
      if (r == null) return;
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = r.files.first.bytes;
      } else {
        final path = r.files.first.path;
        if (path != null) bytes = await File(path).readAsBytes();
      }
      if (bytes != null && mounted) setState(() => _avatarBytes = bytes);
    } catch (_) {}
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
          isDark: isDark,
          isAr: isAr,
          title: isAr ? 'تسجيل الخروج' : 'Sign Out',
          body: isAr ? 'هل أنت متأكد؟' : 'Are you sure?',
          confirmLabel: s.profileLogout,
          confirmColor: AppColors.rose),
    );
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    final bg = isDark ? const Color(0xFF0E1117) : const Color(0xFFF7F8FC);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
      body: state.isLoading
          ? _LoadingView(isDark: isDark)
          : state.profile == null
              ? _ErrorView(
                  s: s,
                  onRetry: () =>
                      ref.read(profileProvider.notifier).loadProfile())
              : _ProfileBody(
                  profile: state.profile!,
                  isDark: isDark,
                  isAr: isAr,
                  s: s,
                  tabs: _tabs,
                  avatarBytes: _avatarBytes,
                  editMode: _editMode,
                  onPickAvatar: _pickAvatar,
                  onToggleEdit: () => setState(() => _editMode = !_editMode),
                  onLogout: _logout,
                  isSaving: state.isSaving,
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MAIN BODY
// ══════════════════════════════════════════════════════════════════
class _ProfileBody extends ConsumerWidget {
  final UserProfile profile;
  final bool isDark, isAr, editMode, isSaving;
  final AppStrings s;
  final TabController tabs;
  final Uint8List? avatarBytes;
  final VoidCallback onPickAvatar, onToggleEdit, onLogout;

  const _ProfileBody({
    required this.profile,
    required this.isDark,
    required this.isAr,
    required this.s,
    required this.tabs,
    required this.avatarBytes,
    required this.editMode,
    required this.onPickAvatar,
    required this.onToggleEdit,
    required this.onLogout,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalState = ref.watch(goalProvider);
    final activeGoals = goalState.goals.where((g) => g.isActive).length;
    final achievedGoals = goalState.goals.where((g) => g.isAchieved).length;
    final top = MediaQuery.of(context).padding.top;

    return Column(children: [
      SizedBox(height: top),

      // ── Top bar ───────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _TopBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.go('/home'),
              isDark: isDark),
          const Spacer(),
          Text(isAr ? 'الملف الشخصي' : 'My Profile',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const Spacer(),
          _TopBtn(
              icon: Icons.logout_rounded,
              onTap: onLogout,
              isDark: isDark,
              color: AppColors.rose),
        ]),
      ),

      // ── Scrollable content ────────────────────────────────────
      Expanded(
          child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          // ── Hero ───────────────────────────────────────────────
          _HeroSection(
              profile: profile,
              isDark: isDark,
              isAr: isAr,
              avatarBytes: avatarBytes,
              onPickAvatar: onPickAvatar,
              onEditToggle: onToggleEdit,
              editMode: editMode),

          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────────────────
          _StatsRow(
              profile: profile,
              isDark: isDark,
              isAr: isAr,
              activeGoals: activeGoals,
              achievedGoals: achievedGoals),

          const SizedBox(height: 24),

          // ── Achievements collapsible ───────────────────────────
          _AchievementsRow(
              interviewCount: profile.totalInterviews,
              avgScore: profile.avgScore ?? 0,
              achievedGoals: achievedGoals,
              isDark: isDark,
              isAr: isAr),

          const SizedBox(height: 24),

          // ── Tab segmented control ─────────────────────────────
          _SegmentedTabs(tabs: tabs, isDark: isDark, isAr: isAr),

          const SizedBox(height: 4),

          // ── Tab content ────────────────────────────────────────
          SizedBox(
            height: editMode ? null : null,
            child: _InlineTabContent(
              tabs: tabs,
              profile: profile,
              isDark: isDark,
              isAr: isAr,
              s: s,
              isSaving: isSaving,
            ),
          ),

          const SizedBox(height: 110),
        ]),
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// HERO SECTION — centered avatar, name, role
// ══════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final UserProfile profile;
  final bool isDark, isAr, editMode;
  final Uint8List? avatarBytes;
  final VoidCallback onPickAvatar, onEditToggle;
  const _HeroSection(
      {required this.profile,
      required this.isDark,
      required this.isAr,
      required this.avatarBytes,
      required this.editMode,
      required this.onPickAvatar,
      required this.onEditToggle});

  @override
  Widget build(BuildContext context) => Column(children: [
        // Avatar
        Stack(alignment: Alignment.center, children: [
          // Soft glow behind avatar
          Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.violet.withValues(alpha: 0.20),
                  Colors.transparent,
                ]),
              )),
          // Avatar
          GestureDetector(
            onTap: onPickAvatar,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]),
              child: ClipOval(
                child: avatarBytes != null
                    ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)),
                        child: Center(
                            child: Text(profile.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900)))),
              ),
            ),
          ),
          // Camera badge
          Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: onPickAvatar,
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: AppColors.violet,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                isDark ? const Color(0xFF0E1117) : Colors.white,
                            width: 2.5)),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 13)),
              )),
        ]),

        const SizedBox(height: 14),

        // Name
        Text(profile.displayName,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 4),

        // Job title
        if (profile.jobTitle?.isNotEmpty == true)
          Text(profile.jobTitle!,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: 0.38))),
        const SizedBox(height: 3),

        // Email
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.alternate_email_rounded,
              size: 12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.26)),
          const SizedBox(width: 4),
          Text(profile.email,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.38))),
        ]),

        const SizedBox(height: 16),

        // Edit profile button
        GestureDetector(
          onTap: onEditToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
            decoration: BoxDecoration(
              color: editMode
                  ? AppColors.violet
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: editMode
                      ? AppColors.violet
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(editMode ? Icons.close_rounded : Icons.edit_rounded,
                  size: 14,
                  color: editMode
                      ? Colors.white
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.60)
                          : Colors.black.withValues(alpha: 0.54))),
              const SizedBox(width: 6),
              Text(
                  editMode
                      ? (isAr ? 'إلغاء' : 'Cancel')
                      : (isAr ? 'تعديل الملف' : 'Edit Profile'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: editMode
                          ? Colors.white
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.60)
                              : Colors.black.withValues(alpha: 0.54)))),
            ]),
          ),
        ),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// STATS ROW — pill cards (reference: Bossie Cooper 06 / 25 style)
// ══════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final UserProfile profile;
  final bool isDark, isAr;
  final int activeGoals, achievedGoals;
  const _StatsRow(
      {required this.profile,
      required this.isDark,
      required this.isAr,
      required this.activeGoals,
      required this.achievedGoals});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _StatPill(
            value: '${profile.totalInterviews}',
            label: isAr ? 'مقابلة' : 'Interviews',
            icon: Icons.mic_rounded,
            color: AppColors.violet,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatPill(
            value: profile.avgScore != null
                ? '${profile.avgScore!.toInt()}%'
                : '—',
            label: isAr ? 'المتوسط' : 'Avg Score',
            icon: Icons.star_rounded,
            color: AppColors.amber,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatPill(
            value: '$activeGoals',
            label: isAr ? 'أهداف' : 'Goals',
            icon: Icons.flag_rounded,
            color: AppColors.emerald,
            isDark: isDark,
            onTap: () => context.go('/goals'),
          ),
          const SizedBox(width: 10),
          _StatPill(
            value: '$achievedGoals',
            label: isAr ? 'محقق' : 'Done',
            icon: Icons.emoji_events_rounded,
            color: AppColors.cyan,
            isDark: isDark,
            onTap: () => context.go('/goals'),
          ),
        ]),
      );
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  const _StatPill(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color,
      required this.isDark,
      this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181C25) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 16)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.30)
                          : Colors.black.withValues(alpha: 0.30)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// ACHIEVEMENTS — compact collapsible row
// ══════════════════════════════════════════════════════════════════
class _AchievementsRow extends StatefulWidget {
  final int interviewCount, achievedGoals;
  final double avgScore;
  final bool isDark, isAr;
  const _AchievementsRow(
      {required this.interviewCount,
      required this.avgScore,
      required this.achievedGoals,
      required this.isDark,
      required this.isAr});
  @override
  State<_AchievementsRow> createState() => _AchievementsRowState();
}

class _AchievementsRowState extends State<_AchievementsRow>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  int get _unlocked {
    int n = 0;
    if (widget.interviewCount >= 1) n++;
    if (widget.avgScore >= 80) n++;
    if (widget.achievedGoals >= 1) n++;
    if (widget.interviewCount >= 10) n++;
    return n.clamp(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF181C25) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // Header tile
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(_open ? 0 : 18),
                bottomRight: Radius.circular(_open ? 0 : 18),
              ),
              boxShadow: _open
                  ? []
                  : [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: widget.isDark ? 0.20 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
            ),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.amber, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.isAr ? 'الإنجازات' : 'Achievements',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E))),
                    Text(
                        widget.isAr
                            ? 'أتممت ${widget.interviewCount} مقابلة'
                            : '${widget.interviewCount} interviews completed',
                        style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.38)
                                : Colors.black.withValues(alpha: 0.38))),
                  ])),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$_unlocked/8',
                    style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => Transform.rotate(
                        angle: _anim.value * 3.14159,
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.38)
                                : Colors.black.withValues(alpha: 0.38),
                            size: 20),
                      )),
            ]),
          ),
        ),
        // Expandable
        SizeTransition(
          sizeFactor: _anim,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: widget.isDark ? 0.20 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: AchievementsWidget(
              interviewCount: widget.interviewCount,
              avgScore: widget.avgScore,
              streak: 0,
              resumeCount: widget.interviewCount > 0 ? 1 : 0,
              roadmapCount: 1,
              goalsAchieved: widget.achievedGoals,
              isDark: widget.isDark,
              isAr: widget.isAr,
              compact: true,
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SEGMENTED TABS — pill style (reference: clean fintech tabs)
// ══════════════════════════════════════════════════════════════════
class _SegmentedTabs extends StatelessWidget {
  final TabController tabs;
  final bool isDark, isAr;
  const _SegmentedTabs(
      {required this.tabs, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF181C25)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: tabs,
            indicator: BoxDecoration(
              color: isDark ? const Color(0xFF2D2F3E) : Colors.white,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            dividerColor: Colors.transparent,
            labelColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
            unselectedLabelColor: isDark
                ? Colors.white.withValues(alpha: 0.38)
                : Colors.black.withValues(alpha: 0.38),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: [
              Tab(text: isAr ? 'عام' : 'General'),
              Tab(text: isAr ? 'الإعدادات' : 'Settings'),
              Tab(text: isAr ? 'الأمان' : 'Security'),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// INLINE TAB CONTENT — no separate scrollview per tab
// ══════════════════════════════════════════════════════════════════
class _InlineTabContent extends ConsumerWidget {
  final TabController tabs;
  final UserProfile profile;
  final bool isDark, isAr, isSaving;
  final AppStrings s;
  const _InlineTabContent(
      {required this.tabs,
      required this.profile,
      required this.isDark,
      required this.isAr,
      required this.s,
      required this.isSaving});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedBuilder(
        animation: tabs,
        builder: (_, __) {
          switch (tabs.index) {
            case 1:
              return _SettingsContent(isDark: isDark, isAr: isAr, s: s);
            case 2:
              return _SecurityContent(
                  isDark: isDark, isAr: isAr, isSaving: isSaving);
            default:
              return _GeneralContent(
                  profile: profile,
                  isDark: isDark,
                  isAr: isAr,
                  isSaving: isSaving);
          }
        },
      );
}

// ══════════════════════════════════════════════════════════════════
// GENERAL TAB — list rows (reference: My Profile clean list)
// ══════════════════════════════════════════════════════════════════
class _GeneralContent extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isDark, isAr, isSaving;
  const _GeneralContent(
      {required this.profile,
      required this.isDark,
      required this.isAr,
      required this.isSaving});
  @override
  ConsumerState<_GeneralContent> createState() => _GeneralContentState();
}

class _GeneralContentState extends ConsumerState<_GeneralContent> {
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _job = TextEditingController(text: widget.profile.jobTitle);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _location = TextEditingController(text: widget.profile.location);
  late final _linkedin =
      TextEditingController(text: widget.profile.linkedinUrl);
  late final _github = TextEditingController(text: widget.profile.githubUrl);

  @override
  void dispose() {
    for (final c in [_name, _job, _bio, _location, _linkedin, _github]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    await ref.read(profileProvider.notifier).updateProfile(
        fullName: _name.text.trim(),
        jobTitle: _job.text.trim(),
        bio: _bio.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(_okSnack(widget.isAr ? '✅ تم الحفظ' : '✅ Saved!'));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(widget.isAr ? 'المعلومات الأساسية' : 'Basic Info',
              isDark: widget.isDark),
          const SizedBox(height: 10),
          _FormCard(isDark: widget.isDark, children: [
            _FormField(
                label: widget.isAr ? 'الاسم الكامل' : 'Full Name',
                ctrl: _name,
                icon: Icons.person_outline_rounded,
                isDark: widget.isDark),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: widget.isAr ? 'المسمى الوظيفي' : 'Job Title',
                ctrl: _job,
                icon: Icons.work_outline_rounded,
                isDark: widget.isDark),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: widget.isAr ? 'الموقع' : 'Location',
                ctrl: _location,
                icon: Icons.location_on_outlined,
                isDark: widget.isDark),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: widget.isAr ? 'نبذة عنك' : 'Bio',
                ctrl: _bio,
                icon: Icons.notes_rounded,
                isDark: widget.isDark,
                maxLines: 2),
          ]),
          const SizedBox(height: 20),
          _SectionLabel(widget.isAr ? 'الروابط' : 'Links',
              isDark: widget.isDark),
          const SizedBox(height: 10),
          _FormCard(isDark: widget.isDark, children: [
            _FormField(
                label: 'LinkedIn',
                ctrl: _linkedin,
                icon: Icons.link_rounded,
                isDark: widget.isDark),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: 'GitHub',
                ctrl: _github,
                icon: Icons.code_rounded,
                isDark: widget.isDark),
          ]),
          const SizedBox(height: 24),
          _SaveButton(
              label: widget.isAr ? 'حفظ التغييرات' : 'Save Changes',
              loading: widget.isSaving,
              onTap: _save),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// SETTINGS TAB — clean menu rows (reference: My Profile menu list)
// ══════════════════════════════════════════════════════════════════
class _SettingsContent extends ConsumerWidget {
  final bool isDark, isAr;
  final AppStrings s;
  const _SettingsContent(
      {required this.isDark, required this.isAr, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(themeProvider) == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel(isAr ? 'التفضيلات' : 'Preferences', isDark: isDark),
        const SizedBox(height: 10),
        _MenuCard(isDark: isDark, children: [
          _MenuRow(
            isDark: isDark,
            icon: darkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            iconColor:
                darkMode ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
            title: darkMode
                ? (isAr ? 'الوضع الداكن' : 'Dark Mode')
                : (isAr ? 'الوضع الفاتح' : 'Light Mode'),
            trailing: _PillSwitch(
                on: darkMode,
                onTap: () => ref.read(themeProvider.notifier).toggle(context)),
          ),
          _Divider(isDark: isDark),
          _MenuRow(
            isDark: isDark,
            icon: Icons.language_rounded,
            iconColor: AppColors.violet,
            title: isAr ? 'اللغة' : 'Language',
            trailing: const LangToggleButton(),
          ),
        ]),
        const SizedBox(height: 20),
        _SectionLabel(isAr ? 'الإشعارات' : 'Notifications', isDark: isDark),
        const SizedBox(height: 10),
        _MenuCard(isDark: isDark, children: [
          _MenuRow(
              isDark: isDark,
              icon: Icons.notifications_outlined,
              iconColor: AppColors.amber,
              title: isAr ? 'تذكيرات المقابلات' : 'Interview Reminders',
              trailing: _SoonBadge()),
          _Divider(isDark: isDark),
          _MenuRow(
              isDark: isDark,
              icon: Icons.mail_outline_rounded,
              iconColor: AppColors.cyan,
              title: isAr ? 'تنبيهات البريد' : 'Email Alerts',
              trailing: _SoonBadge()),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SECURITY TAB
// ══════════════════════════════════════════════════════════════════
class _SecurityContent extends ConsumerStatefulWidget {
  final bool isDark, isAr, isSaving;
  const _SecurityContent(
      {required this.isDark, required this.isAr, required this.isSaving});
  @override
  ConsumerState<_SecurityContent> createState() => _SecurityContentState();
}

class _SecurityContentState extends ConsumerState<_SecurityContent> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  bool _h1 = true, _h2 = true, _h3 = true;

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    HapticFeedback.mediumImpact();
    final isAr = widget.isAr;
    if (_c1.text.isEmpty) {
      return _err(isAr ? 'أدخل كلمة المرور الحالية' : 'Enter current password');
    }
    if (_c2.text.length < 6) {
      return _err(isAr ? 'كلمة المرور قصيرة جداً' : 'Password too short');
    }
    if (_c2.text != _c3.text) {
      return _err(isAr ? 'كلمتا المرور لا تتطابقان' : "Passwords don't match");
    }
    if (_c2.text == _c1.text) {
      return _err(isAr ? 'يجب أن تكون مختلفة' : 'Must be different');
    }
    final err = await ref
        .read(profileProvider.notifier)
        .updatePassword(currentPassword: _c1.text, newPassword: _c2.text);
    if (!mounted) return;
    if (err == null) {
      _c1.clear();
      _c2.clear();
      _c3.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          _okSnack(widget.isAr ? '✅ تم التحديث' : '✅ Password updated!'));
    } else {
      _err(err);
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('❌ $m'),
      backgroundColor: AppColors.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));

  Future<void> _del() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(
            isDark: widget.isDark,
            isAr: widget.isAr,
            title: '⚠️ ${widget.isAr ? "حذف الحساب؟" : "Delete Account?"}',
            body: widget.isAr ? 'لا يمكن التراجع.' : 'This cannot be undone.',
            confirmLabel: widget.isAr ? 'حذف' : 'Delete',
            confirmColor: AppColors.rose));
    if (ok == true && mounted) {
      final done = await ref.read(profileProvider.notifier).deleteAccount();
      if (mounted && done) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLabel(widget.isAr ? 'تغيير كلمة المرور' : 'Change Password',
              isDark: widget.isDark),
          const SizedBox(height: 10),
          _FormCard(isDark: widget.isDark, children: [
            _FormField(
                label: widget.isAr ? 'الحالية' : 'Current',
                ctrl: _c1,
                icon: Icons.lock_outline_rounded,
                isDark: widget.isDark,
                obs: _h1,
                suf: _EyeBtn(_h1, () => setState(() => _h1 = !_h1))),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: widget.isAr ? 'الجديدة' : 'New',
                ctrl: _c2,
                icon: Icons.lock_rounded,
                isDark: widget.isDark,
                obs: _h2,
                suf: _EyeBtn(_h2, () => setState(() => _h2 = !_h2))),
            _Divider(isDark: widget.isDark),
            _FormField(
                label: widget.isAr ? 'تأكيد' : 'Confirm',
                ctrl: _c3,
                icon: Icons.lock_reset_rounded,
                isDark: widget.isDark,
                obs: _h3,
                suf: _EyeBtn(_h3, () => setState(() => _h3 = !_h3))),
          ]),
          const SizedBox(height: 16),
          _SaveButton(
              label: widget.isAr ? 'تحديث' : 'Update Password',
              loading: widget.isSaving,
              onTap: _update),
          const SizedBox(height: 28),
          // Danger zone
          GestureDetector(
            onTap: _del,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.rose.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.rose, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.isAr ? 'حذف الحساب' : 'Delete Account',
                          style: const TextStyle(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      Text(
                          widget.isAr
                              ? 'إزالة جميع بياناتك'
                              : 'Remove all your data permanently',
                          style: TextStyle(
                              color: AppColors.rose.withValues(alpha: 0.55),
                              fontSize: 11)),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.rose.withValues(alpha: 0.4)),
              ]),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// REUSABLE COMPONENTS
// ══════════════════════════════════════════════════════════════════

// Form card — groups fields with rounded container and shadow
class _FormCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _FormCard({required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C25) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: children),
      );
}

// Menu card — same look as form card
class _MenuCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _MenuCard({required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C25) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: children),
      );
}

// Form field inside a card
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool isDark, obs;
  final int maxLines;
  final Widget? suf;

  const _FormField({
    required this.label,
    required this.ctrl,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.obs = false,
    this.suf,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(icon,
              size: 17,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.26)),
          const SizedBox(width: 12),
          Expanded(
              child: TextFormField(
            controller: ctrl,
            obscureText: obs,
            maxLines: obs ? 1 : maxLines,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: 0.38)),
              suffixIcon: suf,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )),
        ]),
      );
}

// Menu row (icon + title + trailing)
class _MenuRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;
  const _MenuRow(
      {required this.isDark,
      required this.icon,
      required this.iconColor,
      required this.title,
      required this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E)))),
          trailing,
        ]),
      );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 64),
        child: Container(
            height: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.black.withValues(alpha: 0.30)));
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SaveButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap();
              },
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: loading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
            color: loading ? Colors.grey.shade500 : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
          ),
          child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15))),
        ),
      );
}

class _PillSwitch extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _PillSwitch({required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 48,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: on ? AppColors.violet : Colors.grey.shade400),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white)),
          ),
        ),
      );
}

class _SoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: const Text('Soon',
          style: TextStyle(
              color: AppColors.amber,
              fontSize: 10,
              fontWeight: FontWeight.w900)));
}

class _EyeBtn extends StatelessWidget {
  final bool hidden;
  final VoidCallback onTap;
  const _EyeBtn(this.hidden, this.onTap);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
        onPressed: onTap,
        iconSize: 18,
        icon: Icon(
            hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: isDark
                ? Colors.white.withValues(alpha: 0.38)
                : Colors.black.withValues(alpha: 0.38)));
  }
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;
  const _TopBtn(
      {required this.icon,
      required this.onTap,
      required this.isDark,
      this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Icon(icon,
                size: 17,
                color: color ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : Colors.black.withValues(alpha: 0.54)))),
      );
}

class _ConfirmDialog extends StatelessWidget {
  final bool isDark, isAr;
  final String title, body, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog(
      {required this.isDark,
      required this.isAr,
      required this.title,
      required this.body,
      required this.confirmLabel,
      required this.confirmColor});
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF181C25) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(body,
            style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.60)
                    : Colors.black.withValues(alpha: 0.54),
                fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(confirmLabel)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════
// SHIMMER LOADING — matches exact layout shape
// ══════════════════════════════════════════════════════════════════
class _LoadingView extends StatefulWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final v = 0.04 + 0.08 * _a.value;
          final hi = widget.isDark
              ? Colors.white.withValues(alpha: v)
              : Colors.black.withValues(alpha: v);
          final lo = widget.isDark
              ? Colors.white.withValues(alpha: v * 0.4)
              : Colors.black.withValues(alpha: v * 0.4);
          final card = widget.isDark ? const Color(0xFF181C25) : Colors.white;

          Widget bone(double w, double h, {double r = 12, bool fill = false}) =>
              Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                      color: fill ? hi : lo,
                      borderRadius: BorderRadius.circular(r)));

          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(children: [
              SizedBox(height: top),

              // ── Top bar ──────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(children: [
                  bone(40, 40, r: 12),
                  const Spacer(),
                  bone(100, 18, r: 8),
                  const Spacer(),
                  bone(40, 40, r: 12),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Avatar circle ─────────────────────────────────────
              Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: hi)),
              const SizedBox(height: 14),

              // ── Name ─────────────────────────────────────────────
              bone(140, 20, r: 8, fill: true),
              const SizedBox(height: 8),
              // Job title
              bone(100, 13, r: 6),
              const SizedBox(height: 5),
              // Email
              bone(160, 11, r: 5),
              const SizedBox(height: 14),
              // Edit button
              bone(120, 34, r: 20),

              const SizedBox(height: 28),

              // ── Stats row (4 cards) ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                    children: List.generate(
                        4,
                        (i) => Expanded(
                              child: Container(
                                margin: EdgeInsets.only(left: i > 0 ? 10 : 0),
                                height: 88,
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: widget.isDark ? 0.20 : 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Icon circle
                                      Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: hi)),
                                      const SizedBox(height: 8),
                                      // Number
                                      bone(28, 14, r: 5, fill: true),
                                      const SizedBox(height: 5),
                                      // Label
                                      bone(36, 8, r: 4),
                                    ]),
                              ),
                            ))),
              ),

              const SizedBox(height: 24),

              // ── Achievements header ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: widget.isDark ? 0.20 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: hi,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(width: 12),
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bone(100, 13, r: 5, fill: true),
                          const SizedBox(height: 6),
                          bone(70, 10, r: 4),
                        ]),
                    const Spacer(),
                    bone(44, 24, r: 12),
                    const SizedBox(width: 8),
                    bone(20, 20, r: 4),
                  ]),
                ),
              ),

              const SizedBox(height: 24),

              // ── Segmented tabs ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF181C25)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                      children: List.generate(
                          3,
                          (i) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(left: i > 0 ? 4 : 0),
                                  decoration: BoxDecoration(
                                      color: i == 0
                                          ? (widget.isDark
                                              ? const Color(0xFF2D2F3E)
                                              : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11)),
                                  child: Center(
                                      child: bone(i == 0 ? 56 : 44, 10,
                                          r: 4, fill: i == 0)),
                                ),
                              ))),
                ),
              ),

              const SizedBox(height: 16),

              // ── Form card — section label + 3 fields ─────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bone(70, 10, r: 4),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: widget.isDark ? 0.20 : 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                            children: List.generate(
                                3,
                                (i) => Column(children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        child: Row(children: [
                                          bone(17, 17, r: 4),
                                          const SizedBox(width: 12),
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                bone(55, 9, r: 4),
                                                const SizedBox(height: 6),
                                                bone(130, 13, r: 5, fill: true),
                                              ]),
                                        ]),
                                      ),
                                      if (i < 2)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(left: 45),
                                            child: Container(
                                                height: 0.5, color: lo)),
                                    ]))),
                      ),
                    ]),
              ),
            ]),
          );
        });
  }
}

class _ErrorView extends StatelessWidget {
  final AppStrings s;
  final VoidCallback onRetry;
  const _ErrorView({required this.s, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('😕', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: Text(s.retry)),
      ]));
}

SnackBar _okSnack(String m) => SnackBar(
    content: Text(m),
    backgroundColor: AppColors.emerald,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
