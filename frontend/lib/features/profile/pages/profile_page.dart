// lib/features/profile/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/lang_toggle_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: Stack(
        children: [
          const BackgroundPainter(),
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.violet))
              : state.profile == null
                  ? _ErrorState(
                      onRetry: () =>
                          ref.read(profileProvider.notifier).loadProfile(),
                      s: s,
                    )
                  : Column(
                      children: [
                        _CompactPremiumHero(
                          profile: state.profile!,
                          isDark: isDark,
                          onLogout: _logout,
                          s: s,
                        ),
                        _GlassTabBar(tabs: _tabs, isDark: isDark, s: s),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _TabCardWrapper(
                                child: _ProfileForm(
                                    profile: state.profile!,
                                    isDark: isDark,
                                    s: s),
                              ),
                              _TabCardWrapper(
                                child: _SettingsForm(
                                    profile: state.profile!,
                                    isDark: isDark,
                                    s: s),
                              ),
                              _TabCardWrapper(
                                child: _SecurityForm(isDark: isDark, s: s),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }
}

class _TabCardWrapper extends StatelessWidget {
  final Widget child;
  const _TabCardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassCard(isDark: isDark, child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────
class _CompactPremiumHero extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;
  final VoidCallback onLogout;
  final AppStrings s;

  const _CompactPremiumHero({
    required this.profile,
    required this.isDark,
    required this.onLogout,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Text(s.profileTitle.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // const LangToggleButton(),
                const SizedBox(width: 4),
                const ThemeToggleButton(),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.white70, size: 20),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      profile.email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.jobTitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.jobTitle!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _heroStat('${profile.totalInterviews}', s.homeInterviews),
                  const SizedBox(height: 6),
                  _heroStat(
                    profile.avgScore != null
                        ? profile.avgScore!.toStringAsFixed(1)
                        : '—',
                    s.homeAvgScore,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String val, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(val,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────────────────────
class _GlassTabBar extends StatelessWidget {
  final TabController tabs;
  final bool isDark;
  final AppStrings s;
  const _GlassTabBar(
      {required this.tabs, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: tabs,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: AppColors.violet),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        labelColor: isDark ? Colors.white : AppColors.violet,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
        tabs: [
          Tab(
              text: Directionality.of(context) == TextDirection.rtl
                  ? 'عام'
                  : 'General'),
          Tab(
              text: Directionality.of(context) == TextDirection.rtl
                  ? 'الإعدادات'
                  : 'Settings'),
          Tab(
              text: Directionality.of(context) == TextDirection.rtl
                  ? 'الأمان'
                  : 'Security'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE FORM
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
          bio: _bio.text.trim(),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${widget.s.success}'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    final s = widget.s;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel(isAr ? 'المعلومات الشخصية' : 'Personal Info'),
        _ProfileTextField(
            controller: _name,
            label: s.authFullName,
            hint: isAr ? 'أحمد الراشد' : 'Your full name',
            icon: Icons.person_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _job,
            label: isAr ? 'المسمى الوظيفي المستهدف' : 'Target Job Title',
            hint: isAr ? 'مثال: مهندس برمجيات' : 'e.g. Software Engineer',
            icon: Icons.work_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _location,
            label: isAr ? 'الموقع' : 'Location',
            hint: isAr ? 'الرياض، السعودية' : 'e.g. Riyadh, Saudi Arabia',
            icon: Icons.location_on_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _bio,
            label: isAr ? 'نبذة عنك' : 'Bio',
            hint: isAr ? 'أخبرنا عن نفسك...' : 'Tell us about yourself...',
            icon: Icons.notes_rounded,
            isDark: widget.isDark,
            maxLines: 3),
        const SizedBox(height: 20),
        _sectionLabel(isAr ? 'الروابط' : 'Links'),
        _ProfileTextField(
            controller: _linkedin,
            label: 'LinkedIn URL',
            hint: 'https://linkedin.com/in/...',
            icon: Icons.link_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _github,
            label: 'GitHub URL',
            hint: 'https://github.com/...',
            icon: Icons.code_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 24),
        PrimaryButton(
            label: isAr ? 'حفظ التغييرات' : 'Save Changes',
            isLoading: isSaving,
            onTap: _save),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS FORM — language switcher now LIVE (not "coming soon")
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isDark;
  final AppStrings s;
  const _SettingsForm(
      {required this.profile, required this.isDark, required this.s});
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🚧 ', style: TextStyle(fontSize: 22)),
          Text(feature,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Text(
          '$feature is coming soon!',
          style: const TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isAr = locale.languageCode == 'ar';
    final isDark = widget.isDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Language — LIVE toggle ─────────────────────────────
        _sectionLabel(isAr ? 'اللغة' : 'Language'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.violet.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language_rounded,
                  color: AppColors.violet, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAr ? 'لغة التطبيق' : 'App Language',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(isAr ? 'العربية مفعّلة الآن' : 'English / العربية',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
            ),
            // Global language toggle button
            const LangToggleButton(),
          ]),
        ),

        const SizedBox(height: 20),
        _sectionLabel(isAr ? 'الإشعارات' : 'Notifications'),
        GestureDetector(
          onTap: () => _showComingSoon(
              context, isAr ? 'تنبيهات البريد' : 'Email Alerts'),
          child: _ComingSoonTile(
            icon: Icons.email_rounded,
            color: AppColors.violet,
            title: isAr ? 'تنبيهات البريد' : 'Email Alerts',
            sub: isAr
                ? 'تذكيرات المقابلات والتحديثات'
                : 'Interview reminders & updates',
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showComingSoon(
              context, isAr ? 'تذكيرات المقابلات' : 'Interview Reminders'),
          child: _ComingSoonTile(
            icon: Icons.notifications_rounded,
            color: AppColors.cyan,
            title: isAr ? 'تذكيرات المقابلات' : 'Interview Reminders',
            sub: isAr
                ? 'إشعارات قبل جلساتك'
                : 'Get notified before your sessions',
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _sectionLabel(isAr ? 'المظهر' : 'Theme'),
        GlassCard(
          isDark: isDark,
          child: Row(children: [
            const Icon(Icons.dark_mode_rounded,
                color: AppColors.violet, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    isAr ? 'الوضع الداكن / الفاتح' : 'Dark / Light Mode',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13))),
            const ThemeToggleButton(),
          ]),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Soon',
              style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY FORM
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityForm extends ConsumerStatefulWidget {
  final bool isDark;
  final AppStrings s;
  const _SecurityForm({required this.isDark, required this.s});
  @override
  ConsumerState<_SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends ConsumerState<_SecurityForm> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    if (_currentPwCtrl.text.isEmpty) {
      _showError(isAr
          ? 'أدخل كلمة المرور الحالية'
          : 'Please enter your current password');
      return;
    }
    if (_newPwCtrl.text.length < 6) {
      _showError(isAr
          ? 'كلمة المرور الجديدة قصيرة جداً'
          : 'New password must be at least 6 characters');
      return;
    }
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      _showError(
          isAr ? 'كلمتا المرور غير متطابقتين' : 'New passwords do not match');
      return;
    }
    if (_newPwCtrl.text == _currentPwCtrl.text) {
      _showError(isAr
          ? 'كلمة المرور الجديدة مطابقة للحالية'
          : 'New password must be different');
      return;
    }

    final error = await ref.read(profileProvider.notifier).updatePassword(
          currentPassword: _currentPwCtrl.text,
          newPassword: _newPwCtrl.text,
        );

    if (!mounted) return;
    if (error == null) {
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAr
            ? '✅ تم تحديث كلمة المرور'
            : '✅ Password updated successfully!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      _showError(error);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('❌ $msg'),
      backgroundColor: AppColors.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _deleteAccount() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف الحساب؟' : 'Delete Account?',
            style: const TextStyle(
                color: AppColors.rose, fontWeight: FontWeight.w800)),
        content: Text(isAr
            ? 'لا يمكن التراجع عن هذا. سيتم حذف جميع بياناتك نهائياً.'
            : 'This cannot be undone. All your data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isAr ? 'حذف نهائي' : 'Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await ref.read(profileProvider.notifier).deleteAccount();
      if (!mounted) return;
      if (ok) {
        context.go('/login');
      } else {
        _showError(isAr
            ? 'فشل حذف الحساب، حاول مجدداً'
            : 'Failed to delete account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel(isAr ? 'تغيير كلمة المرور' : 'Change Password'),
        _ProfileTextField(
          controller: _currentPwCtrl,
          label: isAr ? 'كلمة المرور الحالية' : 'Current Password',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isDark: widget.isDark,
          obscureText: _obscureCurrent,
          suffix: IconButton(
            icon: Icon(
                _obscureCurrent
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: widget.isDark ? Colors.white70 : Colors.black45),
            onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
        ),
        const SizedBox(height: 12),
        _ProfileTextField(
          controller: _newPwCtrl,
          label: isAr ? 'كلمة المرور الجديدة' : 'New Password',
          hint: '••••••••',
          icon: Icons.lock_rounded,
          isDark: widget.isDark,
          obscureText: _obscureNew,
          suffix: IconButton(
            icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: widget.isDark ? Colors.white70 : Colors.black45),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        const SizedBox(height: 12),
        _ProfileTextField(
          controller: _confirmPwCtrl,
          label: isAr ? 'تأكيد كلمة المرور' : 'Confirm New Password',
          hint: '••••••••',
          icon: Icons.lock_reset_rounded,
          isDark: widget.isDark,
          obscureText: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: widget.isDark ? Colors.white70 : Colors.black45),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
            label: isAr ? 'تحديث كلمة المرور' : 'Update Password',
            isLoading: isSaving,
            onTap: _updatePassword),
        const SizedBox(height: 28),
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        _sectionLabel(isAr ? 'منطقة الخطر' : 'Danger Zone'),
        GestureDetector(
          onTap: _deleteAccount,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.delete_forever_rounded,
                  color: AppColors.rose, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.s.profileDelete,
                          style: const TextStyle(
                              color: AppColors.rose,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                          isAr
                              ? 'حذف جميع بياناتك نهائياً'
                              : 'Permanently remove all your data',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.rose.withValues(alpha: 0.5), size: 18),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
      ),
    );

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool isDark, obscureText;
  final int? maxLines;
  final Widget? suffix;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                size: 18, color: isDark ? Colors.white60 : Colors.black45),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: isDark
                    ? const BorderSide(color: Colors.white10)
                    : BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: isDark
                    ? const BorderSide(color: Colors.white10)
                    : BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.violet, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final AppStrings s;
  const _ErrorState({required this.onRetry, required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(s.errUnexpected, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(s.retry,
                  style: const TextStyle(
                      color: AppColors.violet, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}
