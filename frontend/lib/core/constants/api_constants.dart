// lib/core/constants/api_constants.dart
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://10.0.2.2:8000'; // Android emulator → host machine
  }

  // Auth
  static const String authBase = '/api/v1/auth';
  static const String register = '$authBase/register';
  static const String login = '$authBase/login';
  static const String googleAuth = '$authBase/google';
  static const String userProfile = '$authBase/me';
  static const String logout = '$authBase/logout';

  // Features
  static const String interviews = '/api/v1/interviews';
  static const String resumes = '/api/v1/resumes';
  static const String roadmaps = '/api/v1/roadmaps';
}
