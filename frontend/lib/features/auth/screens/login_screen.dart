// lib/features/auth/screens/login_screen.dart
// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../../shared/widgets/lang_toggle_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Single nullable controller — safe on hot reload
  AnimationController? _anim;

  @override
  void initState() {
    super.initState();
    // Synchronous init — no late, no LateInitializationError
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _anim?.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // Helper: derive a 0→1 interval from the master controller
  Animation<double> _interval(double from, double to) => _anim != null
      ? CurvedAnimation(
          parent: _anim!,
          curve: Interval(from, to, curve: Curves.easeOutCubic),
        )
      : const AlwaysStoppedAnimation(1.0);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    final success = await ref.read(authProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (success && mounted) context.go('/home');
  }

  void _showForgotSheet() {
    final emailCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Reset Password',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 6),
            Text('Enter your email to receive a reset link.',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.45),
                  fontSize: 13,
                )),
            const SizedBox(height: 20),
            _AuthField(
              controller: emailCtrl,
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                label: 'Send Reset Link',
                isLoading: false,
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Password reset email sent!'),
                    backgroundColor: AppColors.emerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ));
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final s = AppStrings.of(context);
    final size = MediaQuery.of(context).size;
    final bg = isDark ? const Color(0xFF0A0C12) : const Color(0xFFF6F8FE);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // Background blobs
        _BgBlobs(isDark: isDark, size: size),

        SafeArea(
          child: Column(children: [
            // Top row — fades in first (0→30%)
            FadeTransition(
              opacity: _interval(0.0, 0.4),
              child: _TopRow(isDark: isDark, isAr: isAr),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(children: [
                  // Hero card — scale + fade (0→50%)
                  FadeTransition(
                    opacity: _interval(0.0, 0.5),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _anim ?? const AlwaysStoppedAnimation(1.0),
                          curve: const Interval(0.0, 0.55,
                              curve: Curves.easeOutBack),
                        ),
                      ),
                      child: _HeroCard(isDark: isDark, isAr: isAr),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form card — slides up (30→80%)
                  AnimatedBuilder(
                    animation: _anim ?? const AlwaysStoppedAnimation(1.0),
                    builder: (_, child) {
                      final t = (_anim?.value ?? 1.0).clamp(0.0, 1.0);
                      // Ease the slide: map 0.3→0.8 to 0→1
                      final progress = ((t - 0.3) / 0.5).clamp(0.0, 1.0);
                      final curve = Curves.easeOutCubic.transform(progress);
                      return Opacity(
                        opacity: curve,
                        child: Transform.translate(
                          offset: Offset(0, 40 * (1.0 - curve)),
                          child: child,
                        ),
                      );
                    },
                    child: _FormCard(
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscure: _obscure,
                      isDark: isDark,
                      isAr: isAr,
                      s: s,
                      isLoading: auth.isLoading,
                      error: auth.error,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      onForgot: _showForgotSheet,
                      onGoogle: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Google Sign-In coming soon!'),
                          backgroundColor: AppColors.violet,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer — fades in last (65→100%)
                  FadeTransition(
                    opacity: _interval(0.65, 1.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(s.authNoAccount,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : Colors.black.withValues(alpha: 0.45),
                                )),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(s.authSignUp,
                                  style: const TextStyle(
                                      color: AppColors.violet,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BACKGROUND BLOBS
// ══════════════════════════════════════════════════════════════════
class _BgBlobs extends StatelessWidget {
  final bool isDark;
  final Size size;
  const _BgBlobs({required this.isDark, required this.size});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned(
          top: -size.height * 0.08,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.violet.withValues(alpha: isDark ? 0.12 : 0.07),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.06,
          left: -size.width * 0.15,
          child: Container(
            width: size.width * 0.55,
            height: size.width * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.cyan.withValues(alpha: isDark ? 0.08 : 0.05),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// TOP ROW
// ══════════════════════════════════════════════════════════════════
class _TopRow extends StatelessWidget {
  final bool isDark, isAr;
  const _TopRow({required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.violet, Color(0xFF6D28D9)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text('خطوة',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20),
                  )),
            ]),
            Row(children: [
              const LangToggleButton(),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: const ThemeToggleButton(),
              ),
            ]),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// HERO CARD
// ══════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final bool isDark, isAr;
  const _HeroCard({required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1B3A), const Color(0xFF0E1524)]
                : [const Color(0xFF7C5CFC), const Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: isDark ? 0.25 : 0.3),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(children: [
          // Decorative ring — top right
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
            ),
          ),
          // Smaller ring
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
            ),
          ),
          // Bottom left circle
          Positioned(
            bottom: -18,
            left: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Stat chip — success rate
          Positioned(
            top: 16,
            right: isAr ? null : 20,
            left: isAr ? 20 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('94% Success Rate',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          // Stat chip — user count
          Positioned(
            bottom: 16,
            left: isAr ? null : 20,
            right: isAr ? 20 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_alt_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('12,000+ Users',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          // Center content
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('خطوة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 4),
              Text(
                isAr
                    ? 'مدرّبك الذكي لاجتياز أي مقابلة'
                    : 'Your AI-powered interview coach',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// FORM CARD
// ══════════════════════════════════════════════════════════════════
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscure, isDark, isAr, isLoading;
  final String? error;
  final AppStrings s;
  final VoidCallback onToggleObscure, onSubmit, onForgot, onGoogle;

  const _FormCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.isDark,
    required this.isAr,
    required this.s,
    required this.isLoading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgot,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141720) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isAr ? 'مرحباً بعودتك 👋' : 'Welcome back 👋',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF1A1C20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAr ? 'سجّل دخولك للمتابعة' : 'Sign in to continue your journey',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 22),
            if (error != null) ...[
              _ErrorBanner(message: error!),
              const SizedBox(height: 16),
            ],
            _FieldLabel(label: s.authEmail, isDark: isDark),
            const SizedBox(height: 8),
            _AuthField(
              controller: emailCtrl,
              hint: 'name@example.com',
              icon: Icons.alternate_email_rounded,
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel(label: s.authPassword, isDark: isDark),
            const SizedBox(height: 8),
            _AuthField(
              controller: passwordCtrl,
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              obscureText: obscure,
              suffix: GestureDetector(
                onTap: onToggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
              child: GestureDetector(
                onTap: onForgot,
                child: const Text('Forgot password?',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.violet)),
              ),
            ),
            const SizedBox(height: 20),
            _GradientButton(
                label: s.authSignIn, isLoading: isLoading, onTap: onSubmit),
            const SizedBox(height: 20),
            _OrDivider(isDark: isDark),
            const SizedBox(height: 16),
            _GoogleButton(isDark: isDark, onTap: onGoogle),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// SHARED BUILDING BLOCKS
// ══════════════════════════════════════════════════════════════════
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _GradientButton(
      {required this.label, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isLoading
                ? null
                : const LinearGradient(
                    colors: [AppColors.violet, Color(0xFF6D28D9)]),
            color: isLoading ? AppColors.violet.withValues(alpha: 0.4) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.2)),
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  final bool isDark;
  const _OrDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    return Row(children: [
      Expanded(child: Divider(color: c, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('OR',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
            )),
      ),
      Expanded(child: Divider(color: c, thickness: 1)),
    ]);
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _GoogleButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF6F8FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Text('Continue with Google',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20),
                )),
          ]),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _FieldLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF1A1C20)));
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark, obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1C20),
            fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.25),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon,
              size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35)),
          suffixIcon: suffix,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF6F8FE),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
              )),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.violet, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.rose.withValues(alpha: 0.8), width: 1.2)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.rose, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.rose, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.rose,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════
// PUBLIC ALIASES  (imported by register_screen.dart)
// ══════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const GlassCard({super.key, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141720) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool isDark, obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label: label, isDark: isDark),
        const SizedBox(height: 8),
        _AuthField(
          controller: controller,
          hint: hint,
          icon: icon,
          isDark: isDark,
          obscureText: obscureText,
          suffix: suffix,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ]);
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.isLoading,
      required this.onTap});

  @override
  Widget build(BuildContext context) =>
      _GradientButton(label: label, isLoading: isLoading, onTap: onTap);
}

class HeaderSection extends StatelessWidget {
  final String title, subtitle;
  final bool isDark;
  const HeaderSection(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.psychology_rounded,
              color: AppColors.violet, size: 36),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1C20))),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.45),
                fontSize: 13)),
      ]);
}

class TopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final bool langToggle;
  const TopBar(
      {super.key, this.showBack = false, this.onBack, this.langToggle = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF1A1C20)),
              ),
            )
          else
            const SizedBox(width: 40),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (langToggle) ...[
              const LangToggleButton(),
              const SizedBox(width: 8),
            ],
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: const ThemeToggleButton(),
            ),
          ]),
        ],
      ),
    );
  }
}

class BottomNavText extends StatelessWidget {
  final String mainText, actionText;
  final VoidCallback onTap;
  const BottomNavText(
      {super.key,
      required this.mainText,
      required this.actionText,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(
        child: Text(mainText,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.45))),
      ),
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(actionText,
              style: const TextStyle(
                  color: AppColors.violet,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
      ),
    ]);
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});
  @override
  Widget build(BuildContext context) => _ErrorBanner(message: message);
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _OrDivider(isDark: isDark);
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const SocialButton(
      {super.key,
      required this.label,
      required this.isDark,
      required this.onTap});
  @override
  Widget build(BuildContext context) =>
      _GoogleButton(isDark: isDark, onTap: onTap);
}
