import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../features/auth/providers/auth_provider.dart";
import "../../features/auth/screens/login_screen.dart";
import "../../features/auth/screens/register_screen.dart";
import "../../features/home/screens/home_screen.dart";
import "../../features/resume/presentation/pages/resume_list_page.dart";

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: "/login",
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading      = authState.isLoading;
      final isAuthRoute    = state.matchedLocation == "/login" ||
                             state.matchedLocation == "/register";

      // Still checking auth status
      if (isLoading) return null;

      // Not logged in → go to login
      if (!isAuthenticated && !isAuthRoute) return "/login";

      // Already logged in → skip login page
      if (isAuthenticated && isAuthRoute) return "/home";

      return null;
    },
    routes: [
      // ─── Auth Routes ──────────────────────────────────
      GoRoute(
        path: "/login",
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: "/register",
        builder: (context, state) => const RegisterScreen(),
      ),

      // ─── Main App Routes ──────────────────────────────
      GoRoute(
        path: "/home",
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: "/resumes",
        builder: (context, state) => const ResumeListPage(),
      ),
    ],
  );
});

// Keep AppRouter for compatibility
class AppRouter {
  static GoRouter of(WidgetRef ref) => ref.watch(routerProvider);
}
