// lib/features/auth/screens/register_screen.dart
// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart'; // shared widgets: GlassCard, ModernTextField, etc.

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
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
  bool _obscure = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    // FIX: Clear any lingering error from login screen
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
        );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

                          // Back button + theme toggle
                          TopBar(
                            showBack: true,
                            onBack: () {
                              // FIX: Clear error before going back to login
                              ref.read(authProvider.notifier).clearError();
                              context.go('/login');
                            },
                          ),

                          const Spacer(),

                          // Header
                          HeaderSection(
                            title: 'Create Account',
                            subtitle: 'Join us and start your journey',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 32),

                          // Form card
                          GlassCard(
                            isDark: isDark,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Error banner
                                  if (auth.error != null) ...[
                                    ErrorBanner(message: auth.error!),
                                    const SizedBox(height: 16),
                                  ],

                                  // Full name
                                  ModernTextField(
                                    controller: _nameCtrl,
                                    label: 'Full Name',
                                    hint: 'John Doe',
                                    icon: Icons.person_outline_rounded,
                                    isDark: isDark,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Name required'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Email
                                  ModernTextField(
                                    controller: _emailCtrl,
                                    label: 'Email Address',
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

                                  // Password
                                  ModernTextField(
                                    controller: _passCtrl,
                                    label: 'Password',
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
                                  const SizedBox(height: 24),

                                  // Sign up button
                                  PrimaryButton(
                                    label: 'Sign Up',
                                    isLoading: auth.isLoading,
                                    onTap: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Switch to login
                          BottomNavText(
                            mainText: 'Already have an account?',
                            actionText: 'Sign In',
                            onTap: () {
                              // FIX: Clear error before navigating to login
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
