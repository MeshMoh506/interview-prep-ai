// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _S();
}

class _S extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, .10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(email: _email.text.trim(), password: _pass.text);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
      return;
    }
    final err = ref.read(authProvider).error;
    if (err != null) _toast(err);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ]),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned(
            top: -80, right: -80, child: _blob(260, AppTheme.primary, 0.07)),
        Positioned(
            bottom: -60, left: -60, child: _blob(200, AppTheme.accent, 0.08)),
        Positioned(
            top: 200, left: -40, child: _blob(120, AppTheme.primary, 0.05)),
        SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                          gradient: AppTheme.brandGrad,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.glowPrimary),
                      child: const Icon(Icons.psychology_alt_rounded,
                          color: Colors.white, size: 36)),
                  const SizedBox(height: 20),
                  const Text('Welcome back',
                      style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                          letterSpacing: -0.6)),
                  const SizedBox(height: 6),
                  const Text('Sign in to your account',
                      style: TextStyle(fontSize: 14, color: AppTheme.inkMid)),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppTheme.elevate2),
                    child: Form(
                        key: _form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _lbl('Email address'),
                              const SizedBox(height: 7),
                              TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.ink),
                                  decoration: _dec(
                                      Icons.alternate_email_rounded,
                                      'you@example.com'),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Email is required';
                                    if (!v.contains('@') || !v.contains('.'))
                                      return 'Enter a valid email';
                                    return null;
                                  }),
                              const SizedBox(height: 16),
                              _lbl('Password'),
                              const SizedBox(height: 7),
                              TextFormField(
                                  controller: _pass,
                                  obscureText: _hide,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.ink),
                                  decoration: _dec(
                                      Icons.lock_outline_rounded, '••••••••',
                                      suffix: GestureDetector(
                                          onTap: () =>
                                              setState(() => _hide = !_hide),
                                          child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 4),
                                              child: Icon(
                                                  _hide
                                                      ? Icons
                                                          .visibility_off_outlined
                                                      : Icons
                                                          .visibility_outlined,
                                                  size: 20,
                                                  color: AppTheme.inkLight)))),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Password is required';
                                    if (v.length < 6)
                                      return 'Minimum 6 characters';
                                    return null;
                                  }),
                              const SizedBox(height: 24),
                              PrimaryButton(
                                  label: 'Sign In',
                                  loading: loading,
                                  onTap: _submit),
                            ])),
                  ),
                  const SizedBox(height: 28),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: AppTheme.inkMid, fontSize: 14)),
                    GestureDetector(
                        onTap: () => context.go('/register'),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14))),
                  ]),
                ]),
              )),
        ))),
      ]),
    );
  }

  Widget _blob(double s, Color c, double a) => Container(
      width: s,
      height: s,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: a)));

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.inkMid));

  InputDecoration _dec(IconData icon, String hint, {Widget? suffix}) =>
      InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.inkLight, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: AppTheme.inkLight),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.danger, width: 2)));
}
