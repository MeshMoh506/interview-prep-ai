class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://localhost:8000';
  static const String authBase = '/api/v1/auth';

  static const String register = '$authBase/register';
  static const String login = '$authBase/login';
  static const String googleAuth = '$authBase/google';
  static const String userProfile = '$authBase/me';
  static const String logout = '$authBase/logout';

  static const String interviews = '/api/v1/interviews';
  static const String resumes = '/api/v1/resumes';
  static const String roadmaps = '/api/v1/roadmaps';
}
