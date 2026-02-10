class ApiConstants {
  // Base URL - CHANGE THIS TO YOUR BACKEND URL , web or mobile
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = '/api/v1';

  // Auth Endpoints
  static const String register = '$apiVersion/auth/register';
  static const String login = '$apiVersion/auth/login';
  static const String logout = '$apiVersion/auth/logout';

  // User Endpoints
  static const String userProfile = '$apiVersion/users/me';
}
