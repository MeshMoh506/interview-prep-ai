import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
      fullName: _nameCtrl.text.trim(),
    );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink40  = isDark ? AppColors.darkInk40 : AppColors.lightInk40;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.go('/login'),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Heading ───────────────────────────────────
                Text('Create account',
                  style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text('Start your interview prep journey today',
                  style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),

                // ── Error ─────────────────────────────────────
                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(auth.error!,
                        style: const TextStyle(color: AppColors.rose, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Fields ────────────────────────────────────
                AppTextField(
                  label: 'FULL NAME',
                  hint: 'Meshari Mohammed',
                  controller: _nameCtrl,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name required' : null,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'EMAIL',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.alternate_email, size: 18),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'PASSWORD',
                  hint: 'Min. 8 characters',
                  controller: _passCtrl,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                AppButton(
                  text: 'Create Account',
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 20),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Already have an account? ",
                        style: TextStyle(fontSize: 13, color: ink40)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero, padding: EdgeInsets.zero,
                        ),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
