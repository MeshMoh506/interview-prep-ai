// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = '/api/v1';

  // Auth
  static const String register = '$apiVersion/auth/register';
  static const String login = '$apiVersion/auth/login';

  // Users
  static const String userProfile = '$apiVersion/users/me';

  // Resumes
  static const String resumes = '$apiVersion/resumes';
  static const String templates = '$apiVersion/resumes/templates';
  static const String powerVerbs = '$apiVersion/resumes/power-verbs';
  static String parseResume(int id) => '$apiVersion/resumes/$id/parse-ai';
  static String analyzeResume(int id) => '$apiVersion/resumes/$id/analyze';
  static String checkFormat(int id) => '$apiVersion/resumes/$id/check-format';
  static String matchJob(int id) => '$apiVersion/resumes/$id/match-job';
  static String rewriteAchievements(int id) =>
      '$apiVersion/resumes/$id/rewrite-achievements';
  static String generateResume(int id) => '$apiVersion/resumes/$id/generate';
  static String downloadResume(int id) => '$apiVersion/resumes/$id/download';

  // Interviews
  static const String interviews = '$apiVersion/interviews';

  // Roadmaps
  static const String roadmaps = '$apiVersion/roadmaps';
  static const String dashboardStats = '$apiVersion/roadmaps/stats/summary';
  static String roadmapDetail(int id) => '$apiVersion/roadmaps/$id';
  static String milestoneProgress(int rid, int mid) =>
      '$apiVersion/roadmaps/$rid/milestones/$mid/progress';
  static String resourceComplete(int rid, int resid) =>
      '$apiVersion/roadmaps/$rid/resources/$resid/complete';
  static String roadmapGoals(int id) => '$apiVersion/roadmaps/$id/goals';
  static String roadmapFeedback(int id) => '$apiVersion/roadmaps/$id/feedback';
  static String suggestGoals(int id) =>
      '$apiVersion/roadmaps/$id/suggest-goals';
}
