// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../models/user_model.dart';
import '../../interview/providers/interview_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../resume/providers/resume_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final User? user;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.error,
    this.user,
  });

  factory AuthState.initial() =>
      AuthState(isLoading: false, isAuthenticated: false);
  factory AuthState.loading() =>
      AuthState(isLoading: true, isAuthenticated: false);
  factory AuthState.authenticated(User user) =>
      AuthState(isLoading: false, isAuthenticated: true, user: user);
  factory AuthState.unauthenticated() =>
      AuthState(isLoading: false, isAuthenticated: false);
  factory AuthState.error(String message) =>
      AuthState(isLoading: false, isAuthenticated: false, error: message);

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    User? user,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        error: error ?? this.error,
        user: user ?? this.user,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final result = await _authService.getCurrentUser();
      if (result['success']) {
        state = AuthState.authenticated(User.fromJson(result['user']));
      } else {
        state = AuthState.unauthenticated();
      }
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.register(
        email: email, password: password, fullName: fullName);
    if (result['success']) return await login(email: email, password: password);
    state = AuthState.error(result['message']);
    return false;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _authService.login(email: email, password: password);
    if (result['success']) {
      final userResult = await _authService.getCurrentUser();
      if (userResult['success']) {
        // ── Flush all user-specific data before setting new user ──
        _clearAllUserData();
        state = AuthState.authenticated(User.fromJson(userResult['user']));
        return true;
      }
    }
    state = AuthState.error(result['message']);
    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    // ── Flush all cached data so user2 never sees user1 data ──
    _clearAllUserData();
    state = AuthState.unauthenticated();
  }

  /// Invalidates every provider that holds user-specific data.
  void _clearAllUserData() {
    _ref.invalidate(interviewHistoryProvider);
    _ref.invalidate(interviewSessionProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(resumeProvider);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService, ref);
});
