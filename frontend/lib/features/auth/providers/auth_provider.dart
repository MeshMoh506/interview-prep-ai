import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../models/user_model.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth State
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
  
  factory AuthState.initial() => AuthState(
    isLoading: false,
    isAuthenticated: false,
  );
  
  factory AuthState.loading() => AuthState(
    isLoading: true,
    isAuthenticated: false,
  );
  
  factory AuthState.authenticated(User user) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    user: user,
  );
  
  factory AuthState.unauthenticated() => AuthState(
    isLoading: false,
    isAuthenticated: false,
  );
  
  factory AuthState.error(String message) => AuthState(
    isLoading: false,
    isAuthenticated: false,
    error: message,
  );
  
  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error ?? this.error,
      user: user ?? this.user,
    );
  }
}

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  
  AuthNotifier(this._authService) : super(AuthState.initial()) {
    checkAuthStatus();
  }
  
  // Check if user is already logged in
  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    
    final isLoggedIn = await _authService.isLoggedIn();
    
    if (isLoggedIn) {
      // Get user profile
      final result = await _authService.getCurrentUser();
      if (result['success']) {
        final user = User.fromJson(result['user']);
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } else {
      state = AuthState.unauthenticated();
    }
  }
  
  // Register
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
    
    if (result['success']) {
      // Auto-login after registration
      return await login(email: email, password: password);
    } else {
      state = AuthState.error(result['message']);
      return false;
    }
  }
  
  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _authService.login(
      email: email,
      password: password,
    );
    
    if (result['success']) {
      // Get user profile
      final userResult = await _authService.getCurrentUser();
      if (userResult['success']) {
        final user = User.fromJson(userResult['user']);
        state = AuthState.authenticated(user);
        return true;
      }
    }
    
    state = AuthState.error(result['message']);
    return false;
  }
  
  // Logout
  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.unauthenticated();
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
