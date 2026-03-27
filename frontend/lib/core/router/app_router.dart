// lib/core/router/app_router.dart
// Full updated version — adds /interview/video route
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/resume/presentation/pages/resume_list_page.dart';
import '../../features/resume/presentation/pages/resume_detail_page.dart';
import '../../features/resume/presentation/pages/resume_builder_page.dart';
import '../../features/interview/pages/interview_list_page.dart';
import '../../features/interview/pages/interview_setup_page.dart';
import '../../features/interview/pages/interview_chat_page.dart';
import '../../features/interview/pages/interview_history_page.dart';
import '../../features/interview/pages/interview_video_page.dart'; // ← NEW
import '../../features/roadmap/pages/roadmap_list_page.dart';
import '../../features/roadmap/pages/roadmap_create_page.dart';
import '../../features/roadmap/pages/roadmap_journey_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/goals/pages/goals_list_page.dart';
import '../../features/goals/pages/goal_detail_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    routes: [
      // ── Auth ──────────────────────────────────────────────────────
      GoRoute(
          path: '/login',
          name: 'login',
          builder: (c, s) => const LoginScreen()),
      GoRoute(
          path: '/register',
          name: 'register',
          builder: (c, s) => const RegisterScreen()),

      // ── Home ──────────────────────────────────────────────────────
      GoRoute(
          path: '/home', name: 'home', builder: (c, s) => const HomeScreen()),

      // ── Interview ─────────────────────────────────────────────────
      GoRoute(
          path: '/interview',
          name: 'interview',
          builder: (c, s) => const InterviewListPage()),

      GoRoute(
          path: '/interview/setup',
          name: 'interview-setup',
          builder: (c, s) => const InterviewSetupPage()),

      GoRoute(
          path: '/interview/chat',
          name: 'interview-chat',
          builder: (c, s) => const InterviewChatPage()),

      GoRoute(
          path: '/interview/video',
          name: 'interview-video', // ← NEW
          builder: (c, s) => const InterviewVideoPage()),

      GoRoute(
          path: '/interview/history',
          name: 'interview-history',
          builder: (c, s) => const InterviewHistoryPage()),

      // ── Resume ────────────────────────────────────────────────────
      GoRoute(
          path: '/resume',
          name: 'resume',
          builder: (c, s) => const ResumeListPage()),

      GoRoute(
          path: '/resume/builder',
          name: 'resume-builder',
          builder: (c, s) {
            final idStr = s.uri.queryParameters['id'];
            final id = idStr != null ? int.tryParse(idStr) : null;
            return ResumeBuilderPage(sourceResumeId: id);
          }),

      GoRoute(
          path: '/resume/:id',
          name: 'resume-detail',
          builder: (c, s) {
            final id = int.parse(s.pathParameters['id'] ?? '0');
            final extra = s.extra as Map<String, dynamic>?;
            return ResumeDetailPage(
              resumeId: id,
              goalId: extra?['goalId'] as int?,
              targetRole: extra?['targetRole'] as String?,
              goalTitle: extra?['goalTitle'] as String?,
            );
          }),

      // ── Roadmap ───────────────────────────────────────────────────
      GoRoute(
          path: '/roadmap',
          name: 'roadmap',
          builder: (c, s) => const RoadmapListPage()),
      GoRoute(
          path: '/roadmap/create',
          name: 'roadmap-create',
          builder: (c, s) => const RoadmapCreatePage()),
      GoRoute(
          path: '/roadmap/:id',
          name: 'roadmap-detail',
          builder: (c, s) {
            final id = int.parse(s.pathParameters['id']!);
            return RoadmapJourneyPage(roadmapId: id);
          }),

      // ── Goals ─────────────────────────────────────────────────────
      GoRoute(
          path: '/goals',
          name: 'goals',
          builder: (c, s) => const GoalsListPage()),
      GoRoute(
          path: '/goals/:id',
          name: 'goal-detail',
          builder: (c, s) {
            final id = int.parse(s.pathParameters['id']!);
            return GoalDetailPage(goalId: id);
          }),

      // ── Profile ───────────────────────────────────────────────────
      GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (c, s) => const ProfilePage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Page not found: ${state.uri}'),
        const SizedBox(height: 24),
        ElevatedButton(
            onPressed: () => context.go('/home'), child: const Text('Go Home')),
      ])),
    ),
  );
}
