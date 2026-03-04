// lib/features/roadmap/services/roadmap_service.dart
import '../../../services/api_service.dart';
import '../models/roadmap_model.dart';

class RoadmapService {
  final ApiService _api;
  RoadmapService(this._api);

  // ── Core CRUD ──────────────────────────────────────────────────────

  Future<List<Roadmap>> getRoadmaps() async {
    final response = await _api.get('/api/v1/roadmaps/');
    return (response.data as List)
        .map((json) => Roadmap.fromJson(json))
        .toList();
  }

  Future<Roadmap> getRoadmap(int id) async {
    final response = await _api.get('/api/v1/roadmaps/$id');
    return Roadmap.fromJson(response.data);
  }

  Future<Roadmap> generateRoadmap({
    required String targetRole,
    String difficulty = 'intermediate',
    int? resumeId,
  }) async {
    final response = await _api.post(
      '/api/v1/roadmaps/generate',
      queryParameters: {
        'target_role': targetRole,
        'difficulty': difficulty,
        if (resumeId != null) 'resume_id': resumeId,
      },
    );
    return Roadmap.fromJson(response.data);
  }

  Future<Map<String, dynamic>> completeTask(int roadmapId, int taskId) async {
    final response =
        await _api.post('/api/v1/roadmaps/$roadmapId/tasks/$taskId/complete');
    return response.data;
  }

  Future<void> deleteRoadmap(int id) async {
    await _api.delete('/api/v1/roadmaps/$id');
  }

  // ── Resources ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTaskResources(
      int roadmapId, int taskId) async {
    try {
      final response =
          await _api.get('/api/v1/roadmaps/$roadmapId/tasks/$taskId/resources');
      return (response.data['resources'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<bool> addTaskResource(
      int roadmapId, int taskId, Map<String, dynamic> resource) async {
    try {
      await _api.post(
        '/api/v1/roadmaps/$roadmapId/tasks/$taskId/resources',
        data: resource,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Time Logging ───────────────────────────────────────────────────

  Future<bool> logStudyTime(int roadmapId, int taskId, int minutes) async {
    try {
      await _api.put(
        '/api/v1/roadmaps/$roadmapId/tasks/$taskId/time-log',
        data: {'minutes': minutes},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Analytics ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getRoadmapAnalytics(int roadmapId) async {
    try {
      final response = await _api.get('/api/v1/roadmaps/$roadmapId/analytics');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
