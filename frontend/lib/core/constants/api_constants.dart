// lib/core/constants/api_constants.dart
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConstants {
  ApiConstants._();

  static const String _productionUrl =
      'https://cheerful-flow-production-a98e.up.railway.app';

  static String get baseUrl {
    if (kIsWeb) return _productionUrl;
    if (kReleaseMode) return _productionUrl;
    return 'http://10.0.2.2:8000';
  }

  // ── Auth ──────────────────────────────────────────────────────
  static const String authBase = '/api/v1/auth';
  static const String register = '$authBase/register';
  static const String login = '$authBase/login';
  static const String googleAuth = '$authBase/google';
  static const String userProfile = '$authBase/me';
  static const String logout = '$authBase/logout';

  // ── Users (profile management) ────────────────────────────────
  static const String usersMe = '/api/v1/users/me';
  static const String usersMePassword = '/api/v1/users/me/change-password';
  static const String usersMeStats = '/api/v1/users/me/stats';
  static const String usersMeAiProfile = '/api/v1/users/me/ai-profile';

  // ── Features — trailing slash matches FastAPI router prefix ───
  static const String interviews = '/api/v1/interviews/';
  static const String resumes = '/api/v1/resumes/';
  static const String roadmaps = '/api/v1/roadmaps/';
  static const String goals = '/api/v1/goals/';
  static const String practice = '/api/v1/practice/';
  static const String dashboard = '/api/v1/dashboard/';
}
