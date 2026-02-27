// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../../../models/user.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../resume/providers/resume_provider.dart';
import '../../interview/providers/interview_provider.dart';
import '../../roadmap/providers/roadmap_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? token;
  final User? user;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.token,
    this.user,
  });

  // FIX: Added `clearError` flag so null can be explicitly assigned.
  // The old version had `error: error` which always overwrote to null
  // even when no error was passed — breaking the error display on login.
  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool clearError = false,
    String? token,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final _authService = AuthService();

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  // ── Check existing session on app start ──────────────────────────────────
  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    if (isLoggedIn) {
      final result = await _authService.getCurrentUser();
      if (!mounted) return;
      if (result['success'] == true) {
        state = state.copyWith(
          isAuthenticated: true,
          user: User.fromJson(result['user']),
        );
      }
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.login(email: email, password: password);
    if (!mounted) return false;

    if (result['success'] == true) {
      final profileResult = await _authService.getCurrentUser();
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: result['token'],
        user: profileResult['success'] == true
            ? User.fromJson(profileResult['user'])
            : null,
      );
      _safeInvalidateProviders();
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Login failed. Please try again.',
    );
    return false;
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.register(
      email: email,
      password: password,
      fullName: fullName,
    );
    if (!mounted) return false;

    if (result['success'] == true) {
      // Auto-login after successful registration
      return await login(email: email, password: password);
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Registration failed. Please try again.',
    );
    return false;
  }

  // ── Google Login ──────────────────────────────────────────────────────────
  Future<bool> googleLogin({required String idToken}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.googleAuth(idToken: idToken);
    if (!mounted) return false;

    if (result['success'] == true) {
      final profileResult = await _authService.getCurrentUser();
      if (!mounted) return false;

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: result['token'],
        user: profileResult['success'] == true
            ? User.fromJson(profileResult['user'])
            : null,
      );
      _safeInvalidateProviders();
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Google login failed.',
    );
    return false;
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _safeInvalidateProviders();
    if (mounted) state = const AuthState();
  }

  // ── Clear error (used when navigating between login/register) ─────────────
  void clearError() {
    if (mounted) state = state.copyWith(clearError: true);
  }

  // ── Invalidate all data providers on auth change ──────────────────────────
  void _safeInvalidateProviders() {
    Future.microtask(() {
      try {
        _ref.invalidate(dashboardProvider);
      } catch (_) {}
      try {
        _ref.invalidate(resumeProvider);
      } catch (_) {}
      try {
        _ref.invalidate(interviewSessionProvider);
      } catch (_) {}
      try {
        _ref.invalidate(roadmapListProvider);
      } catch (_) {}
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
