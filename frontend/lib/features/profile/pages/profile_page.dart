// lib/features/profile/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/background_painter.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard, PrimaryButton
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                          ref.read(profileProvider.notifier).loadProfile())
                  : Column(
                      children: [
                        _CompactPremiumHero(
                          profile: state.profile!,
                          isDark: isDark,
                          onLogout: _logout,
                        ),
                        _GlassTabBar(tabs: _tabs, isDark: isDark),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _TabCardWrapper(
                                child: _ProfileForm(
                                    profile: state.profile!, isDark: isDark),
                              ),
                              _TabCardWrapper(
                                child: _SettingsForm(
                                    profile: state.profile!, isDark: isDark),
                              ),
                              _TabCardWrapper(
                                child: _SecurityForm(isDark: isDark),
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB CARD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
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
// HERO SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _CompactPremiumHero extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;
  final VoidCallback onLogout;

  const _CompactPremiumHero({
    required this.profile,
    required this.isDark,
    required this.onLogout,
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
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Text('PROFILE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ThemeToggleButton(),
                  IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white70, size: 20),
                    tooltip: 'Sign Out',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Avatar + info
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
              // Stats column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _heroStat('${profile.totalInterviews}', 'Interviews'),
                  const SizedBox(height: 6),
                  _heroStat(
                    profile.avgScore != null
                        ? '${profile.avgScore!.toStringAsFixed(1)}'
                        : '—',
                    'Avg Score',
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
  const _GlassTabBar({required this.tabs, required this.isDark});

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
        tabs: const [
          Tab(text: 'General'),
          Tab(text: 'Settings'),
          Tab(text: 'Security'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE FORM (General tab)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isDark;
  const _ProfileForm({required this.profile, required this.isDark});

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
        content: const Text('✅ Profile updated!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel('Personal Info'),
        _ProfileTextField(
            controller: _name,
            label: 'Full Name',
            hint: 'Your full name',
            icon: Icons.person_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _job,
            label: 'Target Job Title',
            hint: 'e.g. Software Engineer',
            icon: Icons.work_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _location,
            label: 'Location',
            hint: 'e.g. Riyadh, Saudi Arabia',
            icon: Icons.location_on_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 12),
        _ProfileTextField(
            controller: _bio,
            label: 'Bio',
            hint: 'Tell us about yourself...',
            icon: Icons.notes_rounded,
            isDark: widget.isDark,
            maxLines: 3),
        const SizedBox(height: 20),
        _sectionLabel('Links'),
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
        PrimaryButton(label: 'Save Changes', isLoading: isSaving, onTap: _save),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS FORM
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isDark;
  const _SettingsForm({required this.profile, required this.isDark});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _notif;

  @override
  void initState() {
    super.initState();
    _notif = widget.profile.emailNotifications;
  }

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
          '$feature is coming soon! We\'re working hard to bring this feature to you.',
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
    final isSaving = ref.watch(profileProvider).isSaving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel('Notifications'),
        // Email alerts — coming soon
        GestureDetector(
          onTap: () => _showComingSoon(context, 'Email Alerts'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.email_rounded,
                  size: 20, color: AppColors.violet),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email Alerts',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Interview reminders & updates',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
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
          ),
        ),
        const SizedBox(height: 12),
        // Interview reminders — coming soon
        GestureDetector(
          onTap: () => _showComingSoon(context, 'Interview Reminders'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.notifications_rounded,
                  size: 20, color: AppColors.cyan),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interview Reminders',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Get notified before your sessions',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
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
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Language'),
        // Language — coming soon
        GestureDetector(
          onTap: () => _showComingSoon(context, 'Language Settings'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.language_rounded,
                  color: AppColors.violet, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Language',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('English 🇺🇸  •  Arabic 🇸🇦 coming soon',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
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
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Theme'),
        GlassCard(
          isDark: widget.isDark,
          child: Row(children: [
            const Icon(Icons.dark_mode_rounded,
                color: AppColors.violet, size: 20),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Dark / Light Mode',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            const ThemeToggleButton(),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY FORM — FIX: passes current password to provider
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityForm extends ConsumerStatefulWidget {
  final bool isDark;
  const _SecurityForm({required this.isDark});

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
    // Client-side validation
    if (_currentPwCtrl.text.isEmpty) {
      _showError('Please enter your current password');
      return;
    }
    if (_newPwCtrl.text.length < 6) {
      _showError('New password must be at least 6 characters');
      return;
    }
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      _showError('New passwords do not match');
      return;
    }
    if (_newPwCtrl.text == _currentPwCtrl.text) {
      _showError('New password must be different from current password');
      return;
    }

    // FIX: pass BOTH current and new password
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
        content: const Text('✅ Password updated successfully!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      // Show exact error from backend (e.g. "Current password is incorrect")
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?',
            style:
                TextStyle(color: AppColors.rose, fontWeight: FontWeight.w800)),
        content: const Text(
            'This cannot be undone. All your resumes, interviews, and data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Forever'),
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
        _showError('Failed to delete account. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel('Change Password'),
        _ProfileTextField(
          controller: _currentPwCtrl,
          label: 'Current Password',
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
          label: 'New Password',
          hint: '••••••••  (min 6 chars)',
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
          label: 'Confirm New Password',
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
            label: 'Update Password',
            isLoading: isSaving,
            onTap: _updatePassword),
        const SizedBox(height: 28),
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        _sectionLabel('Danger Zone'),
        GestureDetector(
          onTap: _deleteAccount,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_forever_rounded,
                    color: AppColors.rose, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delete Account',
                            style: TextStyle(
                                color: AppColors.rose,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text('Permanently remove all your data',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.rose.withValues(alpha: 0.5), size: 18),
              ],
            ),
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
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscureText;
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

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          const Text('Failed to load profile',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(
                    color: AppColors.violet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
