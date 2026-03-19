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
import '../../features/roadmap/pages/roadmap_list_page.dart';
import '../../features/roadmap/pages/roadmap_create_page.dart';
import '../../features/roadmap/pages/roadmap_journey_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/interview/pages/interview_video_page.dart';
import '../../features/interview/pages/interview_history_page.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../shared/widgets/transitions.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Onboarding ────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => AppTransitions.fade(
            key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const ProfileSetupScreen()),
      ),

      // ── Auth ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) =>
            AppTransitions.fade(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => AppTransitions.fade(
            key: state.pageKey, child: const RegisterScreen()),
      ),

      // ── Home ──────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const HomeScreen()),
      ),

      // ── Interview ─────────────────────────────────────────────
      GoRoute(
        path: '/interview/setup',
        name: 'interview-setup',
        pageBuilder: (context, state) => AppTransitions.scale(
            key: state.pageKey, child: const InterviewSetupPage()),
      ),
      GoRoute(
        path: '/interview/chat',
        name: 'interview-chat',
        pageBuilder: (context, state) => AppTransitions.fadeSlideRight(
            key: state.pageKey, child: const InterviewChatPage()),
      ),
      GoRoute(
        path: '/interview/video',
        name: 'interview-video',
        pageBuilder: (context, state) => AppTransitions.fadeSlideRight(
            key: state.pageKey, child: const InterviewVideoPage()),
      ),
      GoRoute(
        path: '/interview/history',
        name: 'interview-history',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const InterviewHistoryPage()),
      ),
      GoRoute(
        path: '/interview',
        name: 'interview',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const InterviewListPage()),
      ),

      // ── Resume ────────────────────────────────────────────────
      GoRoute(
        path: '/resume',
        name: 'resume',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const ResumeListPage()),
      ),
      GoRoute(
        path: '/resume/builder',
        name: 'resume-builder',
        pageBuilder: (context, state) {
          final idStr = state.uri.queryParameters['id'];
          final id = idStr != null ? int.tryParse(idStr) : null;
          return AppTransitions.fadeSlideRight(
              key: state.pageKey, child: ResumeBuilderPage(sourceResumeId: id));
        },
      ),
      GoRoute(
        path: '/resume/:id',
        name: 'resume-detail',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id'] ?? '0');
          return AppTransitions.fadeSlideRight(
              key: state.pageKey, child: ResumeDetailPage(resumeId: id));
        },
      ),

      // ── Roadmap ───────────────────────────────────────────────
      GoRoute(
        path: '/roadmap',
        name: 'roadmap',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const RoadmapListPage()),
      ),
      GoRoute(
        path: '/roadmap/create',
        name: 'roadmap-create',
        pageBuilder: (context, state) => AppTransitions.scale(
            key: state.pageKey, child: const RoadmapCreatePage()),
      ),
      GoRoute(
        path: '/roadmap/:id',
        name: 'roadmap-detail',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AppTransitions.fadeSlideRight(
              key: state.pageKey, child: RoadmapJourneyPage(roadmapId: id));
        },
      ),

      // ── Profile ───────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => AppTransitions.fadeSlideUp(
            key: state.pageKey, child: const ProfilePage()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Page not found: \${state.uri}'),
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
