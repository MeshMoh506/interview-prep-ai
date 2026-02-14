// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
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
import '../../features/shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/login',
      routes: [
        // ── Public (no shell) ──────────────────────────────────
        GoRoute(
            path: '/login', pageBuilder: (c, s) => _fade(const LoginScreen())),
        GoRoute(
            path: '/register',
            pageBuilder: (c, s) => _fade(const RegisterScreen())),

        // ── Authenticated shell ────────────────────────────────
        ShellRoute(
          builder: (ctx, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
                path: '/home',
                pageBuilder: (c, s) => _fade(const HomeScreen())),

            GoRoute(
                path: '/resumes',
                pageBuilder: (c, s) => _fade(const ResumeListPage()),
                routes: [
                  GoRoute(
                      path: ':id',
                      pageBuilder: (c, s) {
                        final id =
                            int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
                        return _slide(ResumeDetailPage(resumeId: id));
                      })
                ]),

            // legacy alias
            GoRoute(
                path: '/resume',
                pageBuilder: (c, s) => _fade(const ResumeListPage())),

            GoRoute(
                path: '/interview',
                pageBuilder: (c, s) => _fade(const InterviewSetupPage()),
                routes: [
                  GoRoute(
                      path: 'chat',
                      pageBuilder: (c, s) => _slide(const InterviewChatPage())),
                  GoRoute(
                      path: 'history',
                      pageBuilder: (c, s) =>
                          _fade(const InterviewHistoryPage())),
                ]),

            GoRoute(
                path: '/roadmap',
                pageBuilder: (c, s) => _fade(const RoadmapHistoryPage()),
                routes: [
                  GoRoute(
                      path: 'setup',
                      pageBuilder: (c, s) => _slide(const RoadmapSetupPage())),
                  GoRoute(
                      path: ':id',
                      pageBuilder: (c, s) {
                        final id =
                            int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
                        return _slide(RoadmapDetailPage(roadmapId: id));
                      }),
                ]),
          ],
        ),
      ],
    ));

// ── Transitions ───────────────────────────────────────────────────
CustomTransitionPage<void> _fade(Widget child) => CustomTransitionPage(
    child: child,
    transitionDuration: const Duration(milliseconds: 230),
    transitionsBuilder: (c, a, _, w) => FadeTransition(opacity: a, child: w));

CustomTransitionPage<void> _slide(Widget child) => CustomTransitionPage(
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (c, a, _, w) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: w));
