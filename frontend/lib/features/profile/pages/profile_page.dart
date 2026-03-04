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
          // Avatar + name
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
  late final TextEditingController _name, _job, _bio;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _job = TextEditingController(text: widget.profile.jobTitle);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(profileProvider.notifier).updateProfile(
          fullName: _name.text.trim(),
          jobTitle: _job.text.trim(),
          bio: _bio.text.trim(),
        ); // matches ProfileNotifier.updateProfile({fullName, jobTitle, bio})
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Profile updated!'),
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
        _ProfileTextField(
            controller: _name,
            label: 'Full Name',
            hint: 'Your full name',
            icon: Icons.person_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 16),
        _ProfileTextField(
            controller: _job,
            label: 'Target Job',
            hint: 'e.g. Software Engineer',
            icon: Icons.work_rounded,
            isDark: widget.isDark),
        const SizedBox(height: 16),
        _ProfileTextField(
            controller: _bio,
            label: 'Bio',
            hint: 'Tell us about yourself...',
            icon: Icons.notes_rounded,
            isDark: widget.isDark,
            maxLines: 3),
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

  Future<void> _save() async {
    await ref.read(profileProvider.notifier).updateSettings(
          emailNotifications: _notif,
        ); // matches ProfileNotifier.updateSettings
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Settings updated!'),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Email Alerts',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87)),
          subtitle: const Text('Interview reminders',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          value: _notif,
          onChanged: (v) => setState(() => _notif = v),
          activeThumbColor: AppColors.violet,
        ),
        const Divider(height: 32, color: Colors.white10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language_rounded, color: AppColors.violet),
          title: Text('Language',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87)),
          trailing:
              const Text('English 🇺🇸', style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Update Settings', isLoading: isSaving, onTap: _save),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY FORM
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityForm extends ConsumerStatefulWidget {
  final bool isDark;
  const _SecurityForm({required this.isDark});

  @override
  ConsumerState<_SecurityForm> createState() => _SecurityFormState();
}

class _SecurityFormState extends ConsumerState<_SecurityForm> {
  final _pwCtrl = TextEditingController();
  final _currentPwCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureCurrent = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _currentPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_currentPwCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Enter your current password'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_pwCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('New password must be at least 8 characters'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final ok = await ref.read(profileProvider.notifier).updatePassword(
          newPassword: _pwCtrl.text,
        );
    if (mounted) {
      _pwCtrl.clear();
      _currentPwCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Password updated!' : 'Failed to update password'),
        backgroundColor: ok ? Colors.green.shade600 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
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
            'This cannot be undone. All your data will be permanently deleted.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // TODO: wire to delete account API endpoint
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const SizedBox(height: 16),
        _ProfileTextField(
          controller: _pwCtrl,
          label: 'New Password',
          hint: '••••••••',
          icon: Icons.lock_rounded,
          isDark: widget.isDark,
          obscureText: _obscure,
          suffix: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: widget.isDark ? Colors.white70 : Colors.black45),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Update Password',
            isLoading: isSaving,
            onTap: _updatePassword),
        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),
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
                  child: Text('Delete Account',
                      style: TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
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
// SHARED TEXT FIELD (multiline + suffix support)
// ─────────────────────────────────────────────────────────────────────────────
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
                fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                size: 20, color: isDark ? Colors.white60 : Colors.black45),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: isDark
                    ? const BorderSide(color: Colors.white10)
                    : BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: isDark
                    ? const BorderSide(color: Colors.white10)
                    : BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.violet, width: 1.5)),
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
