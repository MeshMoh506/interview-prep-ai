// lib/features/interview/services/interview_service.dart
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';

class InterviewService {
  final _api = ApiService();

  Future<Map<String, dynamic>> getAvailableRoles() async {
    try {
      final response = await _api.get('/api/v1/interviews/questions/roles');
      return {'success': true, 'roles': response.data['roles'] ?? []};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    int? resumeId,
  }) async {
    try {
      // NOTE: trailing slash required — backend route is POST /api/v1/interviews/
      final response = await _api.post('/api/v1/interviews/', data: {
        'job_role': jobRole,
        'difficulty': difficulty,
        'interview_type': interviewType,
        'language': language,
        if (resumeId != null) 'resume_id': resumeId,
      });
      return {
        'success': true,
        'session_id': response.data['interview_id'],
        'first_question': response.data['ai_message']['content'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    int sessionId,
    String message, {
    bool useAvatar = false,
    String avatarId = 'professional_female',
  }) async {
    try {
      final endpoint = useAvatar
          ? '/api/v1/interviews/$sessionId/avatar-message'
          : '/api/v1/interviews/$sessionId/message';

      final response = await _api.post(endpoint, data: {
        'content': message,
        if (useAvatar) 'use_avatar': true,
        if (useAvatar) 'avatar_id': avatarId,
      });

      return {
        'success': true,
        'response': response.data['response'] ?? response.data['ai_message']
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendVoice(
    int sessionId,
    List<int> audioBytes,
    String filename, {
    bool useAvatar = false,
    String avatarId = 'professional_female',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes, filename: filename),
        if (useAvatar) 'use_avatar': 'true',
        if (useAvatar) 'avatar_id': avatarId,
      });

      final response = await _api.post(
        '/api/v1/interviews/$sessionId/voice',
        data: formData,
      );

      return {
        'success': true,
        'transcription': response.data['transcription'],
        'response': response.data['response'] ?? response.data['ai_message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> endInterview(int sessionId) async {
    try {
      final response = await _api.post('/api/v1/interviews/$sessionId/end');
      return {
        'success': true,
        'score': response.data['score'],
        'feedback': response.data['feedback'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getInterviewHistory() async {
    try {
      final response = await _api.get('/api/v1/interviews/history');
      final interviews = response.data['interviews'] as List;
      return interviews.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting interview history: $e');
      return [];
    }
  }

  Future<bool> deleteInterview(int id) async {
    try {
      await _api.delete('/api/v1/interviews/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAvailableAvatars() async {
    try {
      final response = await _api.get('/api/v1/interviews/avatars');
      return {'success': true, 'avatars': response.data['avatars'] ?? []};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
