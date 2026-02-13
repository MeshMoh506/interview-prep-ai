import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../features/auth/screens/login_screen.dart";
import "../../features/auth/screens/register_screen.dart";
import "../../features/home/screens/home_screen.dart";
import "../../features/resume/presentation/pages/resume_list_page.dart";
import "../../features/resume/presentation/pages/resume_detail_page.dart";
import "../../features/interview/pages/interview_setup_page.dart";
import "../../features/interview/pages/interview_chat_page.dart";
import "../../features/interview/pages/interview_history_page.dart";

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/login",
    routes: [
      GoRoute(path: "/login", builder: (c, s) => const LoginScreen()),
      GoRoute(path: "/register", builder: (c, s) => const RegisterScreen()),
      GoRoute(path: "/home", builder: (c, s) => const HomeScreen()),

      // Resume — note: home_screen uses /resumes so use that
      GoRoute(path: "/resumes", builder: (c, s) => const ResumeListPage()),
      GoRoute(path: "/resume", builder: (c, s) => const ResumeListPage()),
      GoRoute(
          path: "/resume/:id",
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters["id"] ?? "0") ?? 0;
            return ResumeDetailPage(resumeId: id);
          }),

      // Interview
      GoRoute(
          path: "/interview", builder: (c, s) => const InterviewSetupPage()),
      GoRoute(
          path: "/interview/chat",
          builder: (c, s) => const InterviewChatPage()),
      GoRoute(
          path: "/interview/history",
          builder: (c, s) => const InterviewHistoryPage()),
    ],
  );
});
