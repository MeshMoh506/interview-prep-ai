// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/resume/presentation/pages/resume_list_page.dart';
import '../../features/resume/presentation/pages/resume_detail_page.dart';
import '../../features/interview/pages/interview_setup_page.dart';
import '../../features/interview/pages/interview_chat_page.dart';
import '../../features/interview/pages/interview_history_page.dart';
import '../../features/roadmap/pages/roadmap_setup_page.dart';
import '../../features/roadmap/pages/roadmap_detail_page.dart';
import '../../features/roadmap/pages/roadmap_history_page.dart';
import '../../features/roadmap/providers/roadmap_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),

      // Resume
      GoRoute(path: '/resumes', builder: (c, s) => const ResumeListPage()),
      GoRoute(path: '/resume', builder: (c, s) => const ResumeListPage()),
      GoRoute(
          path: '/resume/:id',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
            return ResumeDetailPage(resumeId: id);
          }),

      // Interview
      GoRoute(
          path: '/interview', builder: (c, s) => const InterviewSetupPage()),
      GoRoute(
          path: '/interview/chat',
          builder: (c, s) => const InterviewChatPage()),
      GoRoute(
          path: '/interview/history',
          builder: (c, s) => const InterviewHistoryPage()),

      // Roadmap  ← fixed: use constructor not function call
      GoRoute(path: '/roadmap', builder: (c, s) => const RoadmapHistoryPage()),
      GoRoute(
          path: '/roadmap/setup', builder: (c, s) => const RoadmapSetupPage()),
      GoRoute(
          path: '/roadmap/:id',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
            return RoadmapDetailPage(roadmapId: id);
          }),
    ],
  );
});
