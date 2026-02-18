import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../models/user_model.dart';
import '../../interview/providers/interview_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../resume/providers/resume_provider.dart';

// Fix: Defining AuthState explicitly so the compiler recognizes it as a type
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final User? user;

  AuthState(
      {required this.isLoading,
      required this.isAuthenticated,
      this.error,
      this.user});

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

  AuthState copyWith(
      {bool? isLoading, bool? isAuthenticated, String? error, User? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error ?? this.error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    if (await _authService.isLoggedIn()) {
      final result = await _authService.getCurrentUser();
      if (result['success']) {
        state = AuthState.authenticated(User.fromJson(result['user']));
      } else {
        state = AuthState.unauthenticated();
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = AuthState.loading();
    final result = await _authService.login(email: email, password: password);
    if (result['success']) {
      final userRes = await _authService.getCurrentUser();
      if (userRes['success']) {
        _clearAllUserData(); // Fantastic: ensures a fresh session
        state = AuthState.authenticated(User.fromJson(userRes['user']));
        return true;
      }
    }
    state = AuthState.error(result['message'] ?? 'Login failed');
    return false;
  }

  Future<bool> register(
      {required String email,
      required String password,
      required String fullName}) async {
    state = AuthState.loading();
    final result = await _authService.register(
        email: email, password: password, fullName: fullName);
    if (result['success']) return login(email: email, password: password);
    state = AuthState.error(result['message'] ?? 'Registration failed');
    return false;
  }

  void logout() {
    _authService.logout();
    _clearAllUserData();
    state = AuthState.unauthenticated();
  }

  void _clearAllUserData() {
    _ref.invalidate(interviewHistoryProvider);
    _ref.invalidate(interviewSessionProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(resumeProvider);
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider), ref);
});
