// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
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
    String? token,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  final _authService = AuthService();

  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final result = await _authService.getCurrentUser();
      if (result['success'] == true) {
        state = state.copyWith(
          isAuthenticated: true,
          user: User.fromJson(result['user']),
        );
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.login(email: email, password: password);

    if (result['success'] == true) {
      final profileResult = await _authService.getCurrentUser();

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
      error: result['message'] ?? 'Login failed',
    );
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.register(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (result['success'] == true) {
      return await login(email: email, password: password);
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Registration failed',
    );
    return false;
  }

  Future<bool> googleLogin({required String idToken}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.googleAuth(idToken: idToken);

    if (result['success'] == true) {
      final profileResult = await _authService.getCurrentUser();

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
      error: result['message'] ?? 'Google login failed',
    );
    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    _safeInvalidateProviders();
    state = const AuthState();
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
      } catch (_) {} // ← FIXED
    });
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
