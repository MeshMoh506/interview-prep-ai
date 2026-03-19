// lib/features/auth/screens/register_screen.dart
// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/background_painter.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          const BackgroundPainter(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          TopBar(
                            showBack: true,
                            langToggle: true,
                            onBack: () {
                              ref.read(authProvider.notifier).clearError();
                              context.go('/login');
                            },
                          ),
                          const Spacer(),
                          HeaderSection(
                            title: s.authSignUp,
                            subtitle: s.authJoinUs,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 32),
                          GlassCard(
                            isDark: isDark,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
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
                                  const SizedBox(height: 16),
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
                                  const SizedBox(height: 16),
                                  ModernTextField(
                                    controller: _passCtrl,
                                    label: s.authPassword,
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    isDark: isDark,
                                    obscureText: _obscure,
                                    suffix: IconButton(
                                      icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black45),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.length < 8)
                                            ? 'At least 8 characters'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  ModernTextField(
                                    controller: _confirmPassCtrl,
                                    label: s.authConfirmPass,
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    isDark: isDark,
                                    obscureText: _obscureConfirm,
                                    suffix: IconButton(
                                      icon: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black45),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
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
                                  const SizedBox(height: 8),
                                  _PasswordStrength(
                                      ctrl: _passCtrl, isDark: isDark),
                                  const SizedBox(height: 20),
                                  Text(
                                    'By signing up you agree to our Terms of Service and Privacy Policy.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  PrimaryButton(
                                    label: s.authSignUp,
                                    isLoading: auth.isLoading,
                                    onTap: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          BottomNavText(
                            mainText: s.authHaveAccount,
                            actionText: s.authSignIn,
                            onTap: () {
                              ref.read(authProvider.notifier).clearError();
                              context.go('/login');
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    widget.ctrl.addListener(() => setState(() {}));
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
    final color = score <= 1
        ? AppColors.rose
        : score <= 2
            ? AppColors.amber
            : score <= 3
                ? AppColors.cyan
                : AppColors.emerald;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final label = score <= 1
        ? (isAr ? 'ضعيفة' : 'Weak')
        : score <= 2
            ? (isAr ? 'مقبولة' : 'Fair')
            : score <= 3
                ? (isAr ? 'جيدة' : 'Good')
                : (isAr ? 'قوية' : 'Strong');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < score
                        ? color
                        : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
