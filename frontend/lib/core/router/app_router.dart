// lib/core/router/app_router.dart
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Home ──────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // ── Interview ─────────────────────────────────────────────────
      GoRoute(
        path: '/interview',
        name: 'interview',
        builder: (context, state) => const InterviewListPage(),
      ),
      GoRoute(
        path: '/interview/setup',
        name: 'interview-setup',
        builder: (context, state) {
          // Accepts extra: {'goalId', 'jobRole', 'difficulty', 'language', 'resumeId'}
          // from goal detail page's Start Interview button
          return const InterviewSetupPage();
        },
      ),
      GoRoute(
        path: '/interview/chat',
        name: 'interview-chat',
        builder: (context, state) => const InterviewChatPage(),
      ),
      GoRoute(
        path: '/interview/history',
        name: 'interview-history',
        builder: (context, state) => const InterviewHistoryPage(),
      ),

      // ── Resume ────────────────────────────────────────────────────
      GoRoute(
        path: '/resume',
        name: 'resume',
        builder: (context, state) => const ResumeListPage(),
      ),
      // IMPORTANT: /resume/builder must come BEFORE /resume/:id
      // so GoRouter doesn't match "builder" as an :id param
      GoRoute(
        path: '/resume/builder',
        name: 'resume-builder',
        builder: (context, state) {
          final idStr = state.uri.queryParameters['id'];
          final id = idStr != null ? int.tryParse(idStr) : null;
          return ResumeBuilderPage(sourceResumeId: id);
        },
      ),
      GoRoute(
        path: '/resume/:id',
        name: 'resume-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id'] ?? '0');
          // Read goal context passed from goal_detail_page
          // extra: {'goalId': int, 'targetRole': String, 'goalTitle': String}
          final extra = state.extra as Map<String, dynamic>?;
          final goalId = extra?['goalId'] as int?;
          final targetRole = extra?['targetRole'] as String?;
          final goalTitle = extra?['goalTitle'] as String?;
          return ResumeDetailPage(
            resumeId: id,
            goalId: goalId,
            targetRole: targetRole,
            goalTitle: goalTitle,
          );
        },
      ),

      // ── Roadmap ───────────────────────────────────────────────────
      GoRoute(
        path: '/roadmap',
        name: 'roadmap',
        builder: (context, state) => const RoadmapListPage(),
      ),
      GoRoute(
        path: '/roadmap/create',
        name: 'roadmap-create',
        builder: (context, state) => const RoadmapCreatePage(),
      ),
      GoRoute(
        path: '/roadmap/:id',
        name: 'roadmap-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RoadmapJourneyPage(roadmapId: id);
        },
      ),

      // ── Goals ─────────────────────────────────────────────────────
      GoRoute(
        path: '/goals',
        name: 'goals',
        builder: (context, state) => const GoalsListPage(),
      ),
      GoRoute(
        path: '/goals/:id',
        name: 'goal-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return GoalDetailPage(goalId: id);
        },
      ),

      // ── Profile ───────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
