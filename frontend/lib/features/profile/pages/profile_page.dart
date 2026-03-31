// lib/features/profile/pages/profile_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/lang_toggle_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../goals/providers/goal_provider.dart'; // ← NEW
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

  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                title: Text(isAr ? 'تسجيل الخروج' : 'Sign Out',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                content: Text(isAr
                    ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                    : 'Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(s.cancel,
                          style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rose,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(s.profileLogout)),
                ]));
    if (confirmed == true && mounted) {
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

    return Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        bottomNavigationBar: const AppBottomNav(currentIndex: 4),
        body: Stack(children: [
          const BackgroundPainter(),
          CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
            // ── App bar ───────────────────────────────────────────────
            SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leadingWidth: 70,
                leading: Center(
                    child: _BoxedNavButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.go('/home'),
                        isDark: isDark)),
                actions: [
                  _BoxedNavButton(
                      icon: Icons.logout_rounded,
                      onTap: _logout,
                      isDark: isDark,
                      color: AppColors.rose),
                  const SizedBox(width: 20),
                ],
                flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.5))))),

            // ── Content ───────────────────────────────────────────────
            if (state.isLoading)
              const _ProfileShimmer()
            else if (state.profile == null)
              SliverFillRemaining(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(s.errUnexpected,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () =>
                            ref.read(profileProvider.notifier).loadProfile(),
                        child: Text(s.retry,
                            style: const TextStyle(
                                color: AppColors.violet,
                                fontWeight: FontWeight.bold))),
                  ])))
            else ...[
              SliverToBoxAdapter(
                  child: _ProfileHero(
                      profile: state.profile!, isDark: isDark, s: s)),
              SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                      child: _PremiumSegmentedTabs(
                          tabs: _tabs, isDark: isDark, isAr: isAr))),
              SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(controller: _tabs, children: [
                    _TabContent(
                        child: _ProfileForm(
                            profile: state.profile!, isDark: isDark, s: s)),
                    _TabContent(child: _SettingsForm(isDark: isDark, s: s)),
                    _TabContent(child: _SecurityForm(isDark: isDark, s: s)),
                  ])),
            ],
          ]),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO — now ConsumerWidget so it can read goalProvider
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHero extends ConsumerWidget {
  // ← changed from StatelessWidget
  final UserProfile profile;
  final bool isDark;
  final AppStrings s;
  const _ProfileHero(
      {required this.profile, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ← added WidgetRef
    // ── Read goal stats ───────────────────────────────────────────────────
    final goalState = ref.watch(goalProvider);
    final activeGoals = goalState.goals.where((g) => g.isActive).length;
    final achievedGoals = goalState.goals.where((g) => g.isAchieved).length;
    final hasGoals = goalState.goals.isNotEmpty;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(children: [
          // Avatar
          Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C5CFC), Color(0xFF00D4FF)]),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF7C5CFC).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10))
                  ]),
              child: Center(
                  child: Text(profile.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)))),

          const SizedBox(height: 18),

          // Name
          Text(profile.displayName,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(profile.email,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500)),

          // Job title pill
          if (profile.jobTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.violet.withValues(alpha: 0.2))),
                child: Text(profile.jobTitle!,
                    style: const TextStyle(
                        color: AppColors.violet,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
          ],

          const SizedBox(height: 20),

          // Interview stats row
          Row(children: [
            _HeroStat(
                value: '${profile.totalInterviews}',
                label: s.homeInterviews,
                color: AppColors.violet,
                isDark: isDark),
            const SizedBox(width: 12),
            _HeroStat(
                value: profile.avgScore != null
                    ? '${profile.avgScore!.toStringAsFixed(1)}%'
                    : '—',
                label: s.homeAvgScore,
                color: AppColors.emerald,
                isDark: isDark),
            const SizedBox(width: 12),
            _HeroStat(
                value: profile.location?.isNotEmpty == true ? '📍' : '—',
                label: profile.location ?? s.noData,
                color: AppColors.cyan,
                isDark: isDark),
          ]),

          // ── Goals stats row ──────────────────────────────────────────
          if (hasGoals) ...[
            const SizedBox(height: 10),
            Row(children: [
              _GoalStatPill(
                icon: Icons.flag_rounded,
                value: '$activeGoals',
                label: isAr ? 'هدف نشط' : 'Active Goals',
                color: AppColors.violet,
                isDark: isDark,
                onTap: () => context.go('/goals'),
              ),
              const SizedBox(width: 10),
              _GoalStatPill(
                icon: Icons.emoji_events_rounded,
                value: '$achievedGoals',
                label: isAr ? 'محقق' : 'Achieved',
                color: AppColors.emerald,
                isDark: isDark,
                onTap: () => context.go('/goals'),
              ),
            ]),
          ],

          const SizedBox(height: 8),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOAL STAT PILL — tappable pill linking to /goals
// ─────────────────────────────────────────────────────────────────────────────
class _GoalStatPill extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _GoalStatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
          child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  Text(label,
                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                      overflow: TextOverflow.ellipsis),
                ])),
          ]),
        ),
      ));
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO STAT — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  final bool isDark;
  const _HeroStat(
      {required this.value,
      required this.label,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.08 : 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTED TABS — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumSegmentedTabs extends StatelessWidget {
  final TabController tabs;
  final bool isDark, isAr;
  const _PremiumSegmentedTabs(
      {required this.tabs, required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Container(
          decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(4),
          child: TabBar(
              controller: tabs,
              indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2))
                  ]),
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.white : AppColors.violet,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              tabs: [
                Tab(text: isAr ? 'عام' : 'General'),
                Tab(text: isAr ? 'الإعدادات' : 'Settings'),
                Tab(text: isAr ? 'الأمان' : 'Security'),
              ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE FORM — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isDark;
  final AppStrings s;
  const _ProfileForm(
      {required this.profile, required this.isDark, required this.s});
  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name,
      _job,
      _bio,
      _location,
      _linkedin,
      _github;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _job = TextEditingController(text: widget.profile.jobTitle);
    _bio = TextEditingController(text: widget.profile.bio);
    _location = TextEditingController(text: widget.profile.location);
    _linkedin = TextEditingController(text: widget.profile.linkedinUrl);
    _github = TextEditingController(text: widget.profile.githubUrl);
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _bio.dispose();
    _location.dispose();
    _linkedin.dispose();
    _github.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(profileProvider.notifier).updateProfile(
        fullName: _name.text.trim(),
        jobTitle: _job.text.trim(),
        bio: _bio.text.trim());
    if (!mounted) return;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAr ? '✅ تم حفظ التغييرات' : '✅ Changes saved!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    final s = widget.s;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Column(children: [
      _sectionLabel(isAr ? 'المعلومات الأساسية' : 'General Info'),
      _PremiumInput(
          label: isAr ? 'الاسم الكامل' : 'Full Name',
          controller: _name,
          icon: Icons.person_rounded,
          isDark: widget.isDark),
      const SizedBox(height: 20),
      _PremiumInput(
          label: isAr ? 'المسمى الوظيفي المستهدف' : 'Target Job Title',
          controller: _job,
          icon: Icons.work_rounded,
          isDark: widget.isDark),
      const SizedBox(height: 20),
      _PremiumInput(
          label: isAr ? 'الموقع' : 'Location',
          controller: _location,
          icon: Icons.location_on_rounded,
          isDark: widget.isDark),
      const SizedBox(height: 20),
      _PremiumInput(
          label: isAr ? 'نبذة عنك' : 'Bio',
          controller: _bio,
          icon: Icons.notes_rounded,
          isDark: widget.isDark,
          maxLines: 3),
      const SizedBox(height: 32),
      _sectionLabel(isAr ? 'الروابط المهنية' : 'Professional Links'),
      _PremiumInput(
          label: 'LinkedIn URL',
          controller: _linkedin,
          icon: Icons.link_rounded,
          isDark: widget.isDark),
      const SizedBox(height: 20),
      _PremiumInput(
          label: 'GitHub URL',
          controller: _github,
          icon: Icons.code_rounded,
          isDark: widget.isDark),
      const SizedBox(height: 40),
      _BigButton(
          label: isAr ? 'حفظ التغييرات' : 'Save Changes',
          isLoading: isSaving,
          onTap: _save),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS FORM — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsForm extends ConsumerWidget {
  final bool isDark;
  final AppStrings s;
  const _SettingsForm({required this.isDark, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Column(children: [
      _sectionLabel(isAr ? 'المظهر' : 'Appearance'),
      _SettingsCard(
          icon: isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
          iconColor:
              isDarkMode ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
          iconBg: isDarkMode
              ? const Color(0xFF818CF8).withValues(alpha: 0.12)
              : const Color(0xFFF59E0B).withValues(alpha: 0.12),
          title: isAr
              ? (isDarkMode ? 'الوضع الداكن' : 'الوضع الفاتح')
              : (isDarkMode ? 'Dark Mode' : 'Light Mode'),
          subtitle: isAr
              ? (isDarkMode
                  ? 'انقر للتبديل إلى الفاتح'
                  : 'انقر للتبديل إلى الداكن')
              : (isDarkMode ? 'Switch to light mode' : 'Switch to dark mode'),
          isDark: isDark,
          trailing: _ThemeSwitch(
              isDarkMode: isDarkMode,
              onToggle: () =>
                  ref.read(themeProvider.notifier).toggle(context))),
      const SizedBox(height: 16),
      _sectionLabel(isAr ? 'اللغة' : 'Language'),
      _SettingsCard(
          icon: Icons.language_rounded,
          iconColor: AppColors.violet,
          iconBg: AppColors.violet.withValues(alpha: 0.12),
          title: isAr ? 'لغة التطبيق' : 'App Language',
          subtitle: isAr
              ? 'التبديل بين العربية والإنجليزية'
              : 'Switch between Arabic & English',
          isDark: isDark,
          trailing: const LangToggleButton()),
      const SizedBox(height: 24),
      _sectionLabel(isAr ? 'الإشعارات' : 'Notifications'),
      _ComingSoonTile(
          icon: Icons.email_rounded,
          color: AppColors.cyan,
          title: isAr ? 'تنبيهات البريد' : 'Email Alerts',
          sub: isAr ? 'تذكيرات وتحديثات' : 'Reminders & updates',
          isDark: isDark),
      const SizedBox(height: 12),
      _ComingSoonTile(
          icon: Icons.notifications_rounded,
          color: AppColors.amber,
          title: isAr ? 'تذكيرات المقابلات' : 'Interview Reminders',
          sub: isAr ? 'إشعارات قبل جلساتك' : 'Notified before sessions',
          isDark: isDark),
    ]);
  }
}

class _ThemeSwitch extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggle;
  const _ThemeSwitch({required this.isDarkMode, required this.onToggle});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 58,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isDarkMode
                  ? const LinearGradient(
                      colors: [Color(0xFF4338CA), Color(0xFF6366F1)])
                  : const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])),
          child: Stack(children: [
            Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                    child: Icon(Icons.wb_sunny_rounded,
                        size: 13,
                        color: isDarkMode ? Colors.white24 : Colors.white))),
            Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                    child: Icon(Icons.nightlight_round,
                        size: 12,
                        color: isDarkMode ? Colors.white : Colors.white24))),
            AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                alignment:
                    isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                curve: Curves.easeInOut,
                child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]),
                    child: Center(
                        child: Icon(
                            isDarkMode
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_rounded,
                            size: 14,
                            color: isDarkMode
                                ? const Color(0xFF4338CA)
                                : const Color(0xFFF59E0B))))),
          ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY FORM — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityForm extends ConsumerStatefulWidget {
  final bool isDark;
  const _SecurityForm({required this.isDark, required AppStrings s});
  @override
  ConsumerState<_SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends ConsumerState<_SecurityForm> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _obscureCur = true, _obscureNew = true, _obscureConf = true;

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    if (_curCtrl.text.isEmpty) {
      _snackError(
          isAr ? 'أدخل كلمة المرور الحالية' : 'Enter your current password');
      return;
    }
    if (_newCtrl.text.length < 6) {
      _snackError(isAr
          ? 'كلمة المرور الجديدة قصيرة جداً (6 أحرف على الأقل)'
          : 'New password must be at least 6 characters');
      return;
    }
    if (_newCtrl.text != _confCtrl.text) {
      _snackError(
          isAr ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match');
      return;
    }
    if (_newCtrl.text == _curCtrl.text) {
      _snackError(isAr
          ? 'كلمة المرور الجديدة مطابقة للحالية'
          : 'New password must be different');
      return;
    }
    final error = await ref.read(profileProvider.notifier).updatePassword(
        currentPassword: _curCtrl.text, newPassword: _newCtrl.text);
    if (!mounted) return;
    if (error == null) {
      _curCtrl.clear();
      _newCtrl.clear();
      _confCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isAr ? '✅ تم تحديث كلمة المرور' : '✅ Password updated!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } else {
      _snackError(error);
    }
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ $msg'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _deleteAccount() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text(isAr ? '⚠️ حذف الحساب؟' : '⚠️ Delete Account?',
                    style: const TextStyle(
                        color: AppColors.rose, fontWeight: FontWeight.w900)),
                content: Text(isAr
                    ? 'لا يمكن التراجع عن هذا. سيتم حذف جميع بياناتك نهائياً.'
                    : 'This cannot be undone. All your data will be permanently deleted.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isAr ? 'إلغاء' : 'Cancel',
                          style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(isAr ? 'حذف نهائي' : 'Delete Forever')),
                ]));
    if (confirmed == true && mounted) {
      final ok = await ref.read(profileProvider.notifier).deleteAccount();
      if (!mounted) return;
      if (ok) {
        context.go('/login');
      } else {
        _snackError(Directionality.of(context) == TextDirection.rtl
            ? 'فشل حذف الحساب'
            : 'Failed to delete account. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Column(children: [
      _sectionLabel(isAr ? 'تغيير كلمة المرور' : 'Change Password'),
      _PremiumInput(
          label: isAr ? 'كلمة المرور الحالية' : 'Current Password',
          controller: _curCtrl,
          icon: Icons.lock_outline_rounded,
          isDark: widget.isDark,
          obscure: _obscureCur,
          suffixIcon: _EyeBtn(
              obscure: _obscureCur,
              isDark: widget.isDark,
              onTap: () => setState(() => _obscureCur = !_obscureCur))),
      const SizedBox(height: 20),
      _PremiumInput(
          label: isAr ? 'كلمة المرور الجديدة' : 'New Password',
          controller: _newCtrl,
          icon: Icons.lock_rounded,
          isDark: widget.isDark,
          obscure: _obscureNew,
          suffixIcon: _EyeBtn(
              obscure: _obscureNew,
              isDark: widget.isDark,
              onTap: () => setState(() => _obscureNew = !_obscureNew))),
      const SizedBox(height: 20),
      _PremiumInput(
          label: isAr ? 'تأكيد كلمة المرور الجديدة' : 'Confirm New Password',
          controller: _confCtrl,
          icon: Icons.lock_reset_rounded,
          isDark: widget.isDark,
          obscure: _obscureConf,
          suffixIcon: _EyeBtn(
              obscure: _obscureConf,
              isDark: widget.isDark,
              onTap: () => setState(() => _obscureConf = !_obscureConf))),
      const SizedBox(height: 32),
      _BigButton(
          label: isAr ? 'تحديث كلمة المرور' : 'Update Password',
          isLoading: isSaving,
          onTap: _updatePassword),
      const SizedBox(height: 32),
      const Divider(color: Colors.white10),
      const SizedBox(height: 16),
      _sectionLabel(isAr ? 'منطقة الخطر' : 'Danger Zone'),
      GestureDetector(
          onTap: _deleteAccount,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.rose.withValues(alpha: 0.2))),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.rose, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(isAr ? 'حذف الحساب' : 'Delete Account',
                          style: const TextStyle(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      Text(
                          isAr
                              ? 'حذف جميع بياناتك نهائياً'
                              : 'Permanently remove all your data',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.rose.withValues(alpha: 0.5), size: 18),
              ]))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS — all unchanged from original
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isDark, obscure;
  final int maxLines;
  final Widget? suffixIcon;
  const _PremiumInput({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isDark,
    this.obscure = false,
    this.maxLines = 1,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.grey))),
        TextFormField(
            controller: controller,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
                prefixIcon: Icon(icon,
                    size: 20, color: AppColors.violet.withValues(alpha: 0.5)),
                suffixIcon: suffixIcon,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                contentPadding: const EdgeInsets.all(20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: AppColors.violet, width: 1.5)))),
      ]);
}

class _EyeBtn extends StatelessWidget {
  final bool obscure, isDark;
  final VoidCallback onTap;
  const _EyeBtn(
      {required this.obscure, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
      icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: isDark ? Colors.white54 : Colors.black38),
      onPressed: onTap);
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final bool isDark;
  final Widget trailing;
  const _SettingsCard(
      {required this.icon,
      required this.iconColor,
      required this.iconBg,
      required this.title,
      required this.subtitle,
      required this.isDark,
      required this.trailing});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05))),
      child: Row(children: [
        Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: iconColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        trailing,
      ]));
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final bool isDark;
  const _ComingSoonTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.sub,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04))),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('Soon',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900))),
      ]));
}

class _BigButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _BigButton(
      {required this.label, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900))));
}

class _BoxedNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;
  const _BoxedNavButton(
      {required this.icon,
      required this.onTap,
      required this.isDark,
      this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
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
                      : Colors.black.withValues(alpha: 0.05))),
          child: Icon(icon,
              size: 18,
              color: color ?? (isDark ? Colors.white70 : Colors.black87))));
}

class _TabContent extends StatelessWidget {
  final Widget child;
  const _TabContent({required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 140),
      child: child);
}

Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5))));

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});
  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Theme.of(context).scaffoldBackgroundColor, child: child);
  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate old) => false;
}

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? const Color(0xFF1E293B) : Colors.white;
    return SliverList(
        delegate: SliverChildListDelegate([
      const SizedBox(height: 20),
      Center(
          child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: BorderRadius.circular(32)))),
      const SizedBox(height: 20),
      Center(
          child: Container(
              width: 160,
              height: 22,
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: BorderRadius.circular(8)))),
      const SizedBox(height: 8),
      Center(
          child: Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: BorderRadius.circular(6)))),
      const SizedBox(height: 24),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
              children: List.generate(
                  3,
                  (i) => Expanded(
                      child: Padding(
                          padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
                          child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                  color: shimmer,
                                  borderRadius:
                                      BorderRadius.circular(16)))))))),
      const SizedBox(height: 24),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
              height: 60,
              decoration: BoxDecoration(
                  color: shimmer, borderRadius: BorderRadius.circular(20)))),
      const SizedBox(height: 24),
      ...List.generate(
          3,
          (i) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(20))))),
    ]));
  }
}
