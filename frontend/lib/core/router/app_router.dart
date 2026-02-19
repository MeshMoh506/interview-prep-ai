import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    
    routes: [
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
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/interview',
        name: 'interview',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/interview/chat/:id',
        name: 'interview-chat',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/interview/results',
        name: 'interview-results',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/resume',
        name: 'resume',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/resume/:id',
        name: 'resume-detail',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/roadmap',
        name: 'roadmap',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const Placeholder(),
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
