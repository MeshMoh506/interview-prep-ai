// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/resume/presentation/pages/resume_list_page.dart';
import '../../features/resume/presentation/pages/resume_detail_page.dart';
import '../../features/resume/presentation/pages/resume_enhance_page.dart';
import '../../features/resume/presentation/pages/resume_ats_page.dart';
import '../../features/resume/presentation/pages/resume_match_page.dart';
import '../../features/resume/presentation/pages/resume_build_page.dart';
import '../../features/resume/presentation/pages/resume_builder_page.dart';
import '../../features/interview/pages/interview_list_page.dart';
import '../../features/interview/pages/interview_setup_page.dart';
import '../../features/interview/pages/interview_chat_page.dart';
import '../../features/interview/pages/interview_history_page.dart';
import '../../features/interview/pages/interview_video_page.dart';
import '../../features/roadmap/pages/roadmap_list_page.dart';
import '../../features/roadmap/pages/roadmap_create_page.dart';
import '../../features/roadmap/pages/roadmap_journey_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/goals/pages/goals_list_page.dart';
import '../../features/goals/pages/goal_detail_page.dart';
import '../../features/goals/pages/goal_create_page.dart';
import '../../features/practice/pages/practice_hub_page.dart';
import '../../features/practice/pages/practice_list_page.dart';
import '../../features/practice/pages/practice_chat_page.dart';

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
          name: 'interview-video',
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
          builder: (c, s) => ResumeBuilderPage(
              sourceResumeId: int.tryParse(s.uri.queryParameters['id'] ?? ''))),
      GoRoute(
          path: '/resume/:id/enhance',
          name: 'resume-enhance',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            final ex = s.extra as Map<String, dynamic>?;
            return ResumeEnhancePage(
                resumeId: id,
                goalId: ex?['goalId'] as int?,
                targetRole: ex?['targetRole'] as String?);
          }),
      GoRoute(
          path: '/resume/:id/ats',
          name: 'resume-ats',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            final ex = s.extra as Map<String, dynamic>?;
            return ResumeAtsPage(resumeId: id, goalId: ex?['goalId'] as int?);
          }),
      GoRoute(
          path: '/resume/:id/match',
          name: 'resume-match',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            final ex = s.extra as Map<String, dynamic>?;
            return ResumeMatchPage(
                resumeId: id,
                goalId: ex?['goalId'] as int?,
                targetRole: ex?['targetRole'] as String?);
          }),
      GoRoute(
          path: '/resume/:id/build',
          name: 'resume-build',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            final ex = s.extra as Map<String, dynamic>?;
            return ResumeBuildPage(resumeId: id, goalId: ex?['goalId'] as int?);
          }),
      GoRoute(
          path: '/resume/:id',
          name: 'resume-detail',
          builder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            final ex = s.extra as Map<String, dynamic>?;
            return ResumeDetailPage(
                resumeId: id,
                goalId: ex?['goalId'] as int?,
                targetRole: ex?['targetRole'] as String?,
                goalTitle: ex?['goalTitle'] as String?);
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
          builder: (c, s) => RoadmapJourneyPage(
              roadmapId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0)),

      // ── Goals ─────────────────────────────────────────────────────
      GoRoute(
          path: '/goals',
          name: 'goals',
          builder: (c, s) => const GoalsListPage()),
      GoRoute(
          path: '/goals/create',
          name: 'goal-create',
          builder: (c, s) => const GoalCreatePage()),
      GoRoute(
          path: '/goals/:id',
          name: 'goal-detail',
          builder: (c, s) => GoalDetailPage(
              goalId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0)),

      // ── Practice Hub ──────────────────────────────────────────────
      // FLAT unique paths — no nesting, no GoRouter conflicts
      GoRoute(
          path: '/practice',
          name: 'practice',
          builder: (c, s) => const PracticeHubPage()),
      GoRoute(
          path: '/practice-history',
          name: 'practice-list',
          builder: (c, s) => const PracticeListPage()),
      GoRoute(
          path: '/practice-chat',
          name: 'practice-chat',
          builder: (c, s) => const PracticeChatPage()),

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
