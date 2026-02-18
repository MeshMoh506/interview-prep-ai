import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hiq_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact(); // Tactile feedback for premium feel
    final success = await ref.read(authProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
    if (success && mounted) {
      context.go('/home');
    } else {
      _shakeCtrl.forward(from: 0.0); // Visual cue for error
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section with corrected height parameter
            const HiqHeroBanner(
              height: 260,
              child: Center(
                child: Icon(Icons.auto_awesome_rounded,
                    size: 60, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: AnimatedBuilder(
                animation: _shakeCtrl,
                builder: (context, child) {
                  final offset =
                      (0.5 - (0.5 - _shakeCtrl.value).abs()) * 2 * 10;
                  return Transform.translate(
                      offset: Offset(offset, 0), child: child);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back',
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 32),
                    if (auth.error != null) _buildError(auth.error!),
                    AppTextField(
                      label: 'EMAIL',
                      controller: _emailCtrl,
                      prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'PASSWORD',
                      controller: _passCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      text: 'Sign In',
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
            color: AppColors.rose.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Text(msg,
            style: const TextStyle(color: AppColors.rose, fontSize: 13)),
      );
}
