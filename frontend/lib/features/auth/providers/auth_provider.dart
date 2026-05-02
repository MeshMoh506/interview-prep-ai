// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../models/user.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../resume/providers/resume_provider.dart';
import '../../interview/providers/interview_provider.dart';
import '../../roadmap/providers/roadmap_provider.dart';

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

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final _authService = AuthService();

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Reload token into ApiService singleton on app start
    await ApiService().reloadToken();
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

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.login(email: email, password: password);
    if (!mounted) return false;

    if (result['success'] == true) {
      // KEY FIX: reload token into singleton IMMEDIATELY after login
      // This ensures all subsequent requests use the new token
      await ApiService().reloadToken();

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
      return await login(email: email, password: password);
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Registration failed. Please try again.',
    );
    return false;
  }

  Future<bool> googleLogin({required String idToken}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _authService.googleAuth(idToken: idToken);
    if (!mounted) return false;

    if (result['success'] == true) {
      await ApiService().reloadToken();
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

  Future<void> updateProfile({
    String? goal,
    String? experienceLevel,
    List<String>? targetIndustries,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (goal != null) body['goal'] = goal;
      if (experienceLevel != null) body['experience_level'] = experienceLevel;
      if (targetIndustries != null) {
        body['target_industries'] = targetIndustries;
      }
      if (body.isEmpty) return;

      final result = await _authService.updateProfile(body);
      if (!mounted) return;
      if (result['success'] == true && result['user'] != null) {
        state = state.copyWith(user: User.fromJson(result['user']));
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await _authService.logout();
    await ApiService().clearToken();
    _safeInvalidateProviders();
    if (mounted) state = const AuthState();
  }

  void clearError() {
    if (mounted) state = state.copyWith(clearError: true);
  }

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

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
