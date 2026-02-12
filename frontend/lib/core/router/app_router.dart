import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../features/auth/screens/login_screen.dart";
import "../../features/auth/screens/register_screen.dart";
import "../../features/home/screens/home_screen.dart";
import "../../features/resume/presentation/pages/resume_list_page.dart";
import "../../features/resume/presentation/pages/resume_detail_page.dart";

// ── Router Provider (matches what main.dart expects) ──────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/login",
    routes: [
      GoRoute(
        path: "/login",
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: "/register",
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: "/home",
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: "/resume",
        builder: (context, state) => const ResumeListPage(),
      ),
      GoRoute(
        path: "/resume/:id",
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters["id"] ?? "0") ?? 0;
          return ResumeDetailPage(resumeId: id);
        },
      ),
    ],
  );
});
