// lib/features/auth/screens/register_screen.dart
// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart'
    show
        TopBar,
        GlassCard,
        ModernTextField,
        PrimaryButton,
        BottomNavText,
        ErrorBanner,
        OrDivider,
        SocialButton;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  // Single nullable controller — hot-reload safe
  AnimationController? _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _anim?.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Animation<double> _interval(double from, double to) => _anim != null
      ? CurvedAnimation(
          parent: _anim!,
          curve: Interval(from, to, curve: Curves.easeOutCubic),
        )
      : const AlwaysStoppedAnimation(1.0);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    final ok = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) context.go('/profile-setup');
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
        _RegBgBlobs(isDark: isDark, size: size),

        SafeArea(
          child: Column(children: [
            // Top bar — fades in (0→35%)
            FadeTransition(
              opacity: _interval(0.0, 0.35),
              child: TopBar(
                showBack: true,
                langToggle: true,
                onBack: () {
                  ref.read(authProvider.notifier).clearError();
                  context.go('/login');
                },
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(children: [
                  // Hero banner — scale + fade (0→50%)
                  FadeTransition(
                    opacity: _interval(0.0, 0.5),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.93, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _anim ?? const AlwaysStoppedAnimation(1.0),
                          curve: const Interval(0.0, 0.55,
                              curve: Curves.easeOutBack),
                        ),
                      ),
                      child: _RegisterHero(isDark: isDark, isAr: isAr),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form card — slides up (30→85%)
                  AnimatedBuilder(
                    animation: _anim ?? const AlwaysStoppedAnimation(1.0),
                    builder: (_, child) {
                      final t = (_anim?.value ?? 1.0).clamp(0.0, 1.0);
                      final progress = ((t - 0.3) / 0.55).clamp(0.0, 1.0);
                      final curve = Curves.easeOutCubic.transform(progress);
                      return Opacity(
                        opacity: curve,
                        child: Transform.translate(
                          offset: Offset(0, 40 * (1.0 - curve)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
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
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'إنشاء حساب جديد ✨'
                                    : 'Create your account ✨',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1C20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAr
                                    ? 'كل الحقول مطلوبة'
                                    : 'Fill in the details below to get started',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 22),

                              if (auth.error != null) ...[
                                ErrorBanner(message: auth.error!),
                                const SizedBox(height: 16),
                              ],

                              ModernTextField(
                                controller: _nameCtrl,
                                label: s.authFullName,
                                hint: 'Ahmed Al-Rashid',
                                icon: Icons.person_outline_rounded,
                                isDark: isDark,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Name required'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              ModernTextField(
                                controller: _emailCtrl,
                                label: s.authEmail,
                                hint: 'name@example.com',
                                icon: Icons.alternate_email_rounded,
                                isDark: isDark,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    (v == null || !v.contains('@'))
                                        ? 'Enter a valid email'
                                        : null,
                              ),
                              const SizedBox(height: 14),

                              ModernTextField(
                                controller: _passCtrl,
                                label: s.authPassword,
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscureText: _obscure,
                                suffix: GestureDetector(
                                  onTap: () =>
                                      setState(() => _obscure = !_obscure),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : Colors.black
                                              .withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 8)
                                    ? 'At least 8 characters'
                                    : null,
                              ),

                              // Password strength meter
                              _PasswordStrength(
                                  ctrl: _passCtrl, isDark: isDark),
                              const SizedBox(height: 14),

                              ModernTextField(
                                controller: _confirmPassCtrl,
                                label: s.authConfirmPass,
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscureText: _obscureConfirm,
                                suffix: GestureDetector(
                                  onTap: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : Colors.black
                                              .withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (v != _passCtrl.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Terms
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.violet.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.violet
                                          .withValues(alpha: 0.1)),
                                ),
                                child: Text(
                                  isAr
                                      ? 'بالتسجيل، أنت توافق على شروط الخدمة وسياسة الخصوصية.'
                                      : 'By signing up you agree to our Terms of Service and Privacy Policy.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.6,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              PrimaryButton(
                                label: s.authSignUp,
                                isLoading: auth.isLoading,
                                onTap: _submit,
                              ),
                            ]),
                      ),
                    ),
                  ), // closes AnimatedBuilder child

                  const SizedBox(height: 24),

                  // Footer fades in last (70→100%)
                  FadeTransition(
                    opacity: _interval(0.7, 1.0),
                    child: BottomNavText(
                      mainText: s.authHaveAccount,
                      actionText: s.authSignIn,
                      onTap: () {
                        ref.read(authProvider.notifier).clearError();
                        context.go('/login');
                      },
                    ),
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
class _RegBgBlobs extends StatelessWidget {
  final bool isDark;
  final Size size;
  const _RegBgBlobs({required this.isDark, required this.size});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned(
          top: -size.height * 0.06,
          left: -size.width * 0.18,
          child: Container(
            width: size.width * 0.65,
            height: size.width * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.cyan.withValues(alpha: isDark ? 0.1 : 0.05),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.05,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.violet.withValues(alpha: isDark ? 0.08 : 0.04),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]);
}

// ══════════════════════════════════════════════════════════════════
// REGISTER HERO BANNER
// ══════════════════════════════════════════════════════════════════
class _RegisterHero extends StatelessWidget {
  final bool isDark, isAr;
  const _RegisterHero({required this.isDark, required this.isAr});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0B2E35), const Color(0xFF0E1524)]
                : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: isDark ? 0.2 : 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(children: [
          // Decorative rings
          Positioned(
            top: -26,
            right: -26,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1.5),
              ),
            ),
          ),
          Positioned(
            bottom: -14,
            left: -14,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Chip — top right
          Positioned(
            top: 16,
            right: isAr ? null : 16,
            left: isAr ? 16 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('AI-Powered',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          // Center
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                isAr ? 'ابدأ رحلتك اليوم!' : 'Start your journey today!',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 3),
              Text(
                isAr
                    ? 'انضم لآلاف المتدربين المحترفين'
                    : 'Join thousands of successful candidates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
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
// PASSWORD STRENGTH METER
// ══════════════════════════════════════════════════════════════════
class _PasswordStrength extends StatefulWidget {
  final TextEditingController ctrl;
  final bool isDark;
  const _PasswordStrength({required this.ctrl, required this.isDark});

  @override
  State<_PasswordStrength> createState() => _PasswordStrengthState();
}

class _PasswordStrengthState extends State<_PasswordStrength> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_rebuild);
    super.dispose();
  }

  int _score(String p) {
    int s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$&*~%^()]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final pass = widget.ctrl.text;
    if (pass.isEmpty) return const SizedBox.shrink();

    final score = _score(pass);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    Color color;
    String label;
    if (score <= 1) {
      color = AppColors.rose;
      label = isAr ? 'ضعيفة' : 'Weak';
    } else if (score <= 2) {
      color = AppColors.amber;
      label = isAr ? 'مقبولة' : 'Fair';
    } else if (score <= 3) {
      color = AppColors.cyan;
      label = isAr ? 'جيدة' : 'Good';
    } else {
      color = AppColors.emerald;
      label = isAr ? 'قوية 💪' : 'Strong 💪';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: List.generate(
              5,
              (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 4,
                      margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i < score
                            ? color
                            : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.07)),
                      ),
                    ),
                  )),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ]),
    );
  }
}
