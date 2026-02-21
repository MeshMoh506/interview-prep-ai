// lib/features/auth/providers/auth_provider.dart - FIXED
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

  /// Check if user is already logged in
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

  /// Login with email/password
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.login(email: email, password: password);

    if (result['success'] == true) {
      // Get user profile
      final profileResult = await _authService.getCurrentUser();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: result['token'],
        user: profileResult['success'] == true
            ? User.fromJson(profileResult['user'])
            : null,
      );

      // FIX: Invalidate all providers to force fresh data for new user
      _invalidateAllProviders();

      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Login failed',
    );
    return false;
  }

  /// Register new user
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
      // Auto-login after registration
      return await login(email: email, password: password);
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Registration failed',
    );
    return false;
  }

  /// Google OAuth login (ready for future implementation)
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

      // FIX: Invalidate all providers to force fresh data for new user
      _invalidateAllProviders();

      return true;
    }

    state = state.copyWith(
      isLoading: false,
      error: result['message'] ?? 'Google login failed',
    );
    return false;
  }

  /// Logout - FIXED to clear all cached data
  Future<void> logout() async {
    await _authService.logout();

    // CRITICAL FIX: Invalidate all user-specific providers
    // This ensures old user's data doesn't show to new user
    _invalidateAllProviders();

    state = const AuthState();
  }

  /// FIX: Invalidate all providers that cache user data
  void _invalidateAllProviders() {
    try {
      // Dashboard
      _ref.invalidate(dashboardProvider);
    } catch (e) {
      // Provider might not exist yet
    }

    try {
      // Resume
      _ref.invalidate(resumeProvider);
    } catch (e) {
      // Provider might not exist yet
    }

    try {
      // Interview
      _ref.invalidate(interviewSessionProvider);
    } catch (e) {
      // Provider might not exist yet
    }

    try {
      // Roadmap
      _ref.invalidate(roadmapsProvider);
    } catch (e) {
      // Provider might not exist yet
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
