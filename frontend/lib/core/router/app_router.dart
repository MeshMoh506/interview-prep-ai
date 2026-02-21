import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/resume/presentation/pages/resume_list_page.dart';
import '../../features/resume/presentation/pages/resume_detail_page.dart';
import '../../features/interview/pages/interview_list_page.dart';
import '../../features/interview/pages/interview_setup_page.dart';
import '../../features/interview/pages/interview_chat_page.dart';
import '../../features/roadmap/pages/roadmap_list_page.dart';
import '../../features/roadmap/pages/roadmap_create_page.dart';
import '../../features/roadmap/pages/roadmap_journey_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    routes: [
      // ── Auth ────────────────────────────────────────────────────
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

      // ── Home ────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // ── Interview ───────────────────────────────────────────────
      GoRoute(
        path: '/interview',
        name: 'interview',
        builder: (context, state) => const InterviewListPage(),
      ),
      GoRoute(
        path: '/interview/setup',
        name: 'interview-setup',
        builder: (context, state) => const InterviewSetupPage(),
      ),
      GoRoute(
        path: '/interview/chat',
        name: 'interview-chat',
        builder: (context, state) => const InterviewChatPage(),
      ),

      // ── Resume ──────────────────────────────────────────────────
      GoRoute(
        path: '/resume',
        name: 'resume',
        builder: (context, state) => const ResumeListPage(),
      ),
      GoRoute(
        path: '/resume/:id',
        name: 'resume-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id'] ?? '0');
          return ResumeDetailPage(resumeId: id);
        },
      ),
      GoRoute(
          path: '/roadmap',
          builder: (context, state) => const RoadmapListPage()),
      GoRoute(
          path: '/roadmap/create',
          builder: (context, state) => const RoadmapCreatePage()),
      GoRoute(
          path: '/roadmap/:id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return RoadmapJourneyPage(roadmapId: id);
          }),
      // ── Roadmap (Placeholder for now) ──────────────────────────
      GoRoute(
        path: '/roadmap',
        name: 'roadmap',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Roadmap')),
          body: const Center(
            child: Text('Coming Soon!', style: TextStyle(fontSize: 20)),
          ),
        ),
      ),

      // ── Profile (Placeholder for now) ──────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: const Center(
            child: Text('Coming Soon!', style: TextStyle(fontSize: 20)),
          ),
        ),
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
