// lib/features/interview/services/interview_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/api_service.dart';

class InterviewService {
  final _api = ApiService();

  Future<Map<String, dynamic>> startInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    int? goalId,
    int? resumeId,
  }) async {
    try {
      final resp = await _api.dio.post('/api/v1/interviews/', data: {
        'job_role': jobRole,
        'difficulty': difficulty,
        'interview_type': interviewType,
        'language': language,
        if (resumeId != null) 'resume_id': resumeId,
        if (goalId != null) 'goal_id': goalId,
      });
      final data = resp.data as Map<String, dynamic>;
      return {
        'success': true,
        'session_id': data['interview_id'],
        'first_question': (data['ai_message'] as Map?)?['content'] ?? '',
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
    String sourceUrl = '',
    String language = 'en',
  }) async {
    try {
      final endpoint = useAvatar
          ? '/api/v1/interviews/$sessionId/avatar-message'
          : '/api/v1/interviews/$sessionId/message';

      final resp = await _api.dio.post(endpoint,
          data: useAvatar
              ? {
                  'content': message,
                  'use_avatar': true,
                  'avatar_id': avatarId,
                  'language': language,
                  if (sourceUrl.isNotEmpty) 'source_url': sourceUrl,
                }
              : {'content': message});

      final data = resp.data as Map<String, dynamic>;

      // ── Backend returns: {"response": {"text": "..."}, ...} ──────
      // Read response.text directly — NOT ai_message.content
      final responseMap = data['response'] as Map? ?? {};
      final text = responseMap['text']?.toString() ??
          responseMap['content']?.toString() ??
          '';

      return {
        'success': true,
        'response': {'text': text},
        'interview_status': data['interview_status'],
        'score': data['score'],
        'feedback': data['feedback'],
        'evaluation': data['evaluation'],
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
    String sourceUrl = '',
    String language = 'en',
  }) async {
    try {
      final endpoint = useAvatar
          ? '/api/v1/interviews/$sessionId/voice-avatar'
          : '/api/v1/interviews/$sessionId/voice';

      const audioType = kIsWeb ? 'webm' : 'm4a';
      final audioSubtype =
          kIsWeb ? DioMediaType('audio', 'webm') : DioMediaType('audio', 'm4a');

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes,
            filename: 'voice.$audioType', contentType: audioSubtype),
        'language': language,
        if (useAvatar) 'avatar_id': avatarId,
        if (useAvatar && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      });

      final resp = await _api.dio.post(endpoint,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            receiveTimeout: const Duration(seconds: 90),
          ));

      final data = resp.data as Map<String, dynamic>;

      if (useAvatar) {
        return {
          'success': data['success'] ?? true,
          'transcription': data['transcription'] ?? '',
          'response': data['response'],
          'interview_status': data['interview_status'],
          'score': data['score'],
          'feedback': data['feedback'],
          'evaluation': data['evaluation'],
        };
      } else {
        // ── Backend /voice returns:
        // {"transcription": "...", "response": {"text": "..."}, ...}
        // OR older format: {"transcript": "...", "ai_message": {"content": "..."}}
        final responseMap = data['response'] as Map?;
        String text = '';
        if (responseMap != null) {
          text = responseMap['text']?.toString() ??
              responseMap['content']?.toString() ??
              '';
        } else {
          // fallback for older backend format
          final aiMsg = data['ai_message'] as Map? ?? {};
          text = aiMsg['content']?.toString() ?? '';
        }

        return {
          'success': true,
          'transcription': data['transcript'] ?? data['transcription'] ?? '',
          'response': {'text': text},
          'interview_status': data['interview_status'],
          'score': data['score'],
          'feedback': data['feedback'],
          'evaluation': data['evaluation'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendVoiceAsync(
    int sessionId,
    List<int> audioBytes,
    String filename, {
    String avatarId = 'professional_female',
    String sourceUrl = '',
    String language = 'en',
  }) async {
    try {
      const audioType = kIsWeb ? 'webm' : 'm4a';
      final audioSubtype =
          kIsWeb ? DioMediaType('audio', 'webm') : DioMediaType('audio', 'm4a');

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes,
            filename: 'voice.$audioType', contentType: audioSubtype),
        'language': language,
        'avatar_id': avatarId,
        if (sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      });

      final resp = await _api.dio
          .post('/api/v1/interviews/$sessionId/voice-avatar-async',
              data: formData,
              options: Options(
                contentType: 'multipart/form-data',
                receiveTimeout: const Duration(seconds: 30),
              ));

      final data = resp.data as Map<String, dynamic>;
      return {'success': true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Stream<Map<String, dynamic>> pollClipStatus(
    String clipId, {
    Duration interval = const Duration(seconds: 3),
    Duration maxWait = const Duration(seconds: 150),
  }) async* {
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      try {
        final resp = await _api.dio.get(
            '/api/v1/interviews/clip-status/$clipId',
            options: Options(receiveTimeout: const Duration(seconds: 10)));
        final data = resp.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';
        yield data;
        if (status == 'done' || status == 'error' || status == 'not_found') {
          return;
        }
      } catch (_) {}
    }
    yield {'status': 'timeout', 'video_url': null};
  }

  Future<Map<String, dynamic>> endInterview(int sessionId) async {
    try {
      final resp = await _api.dio.post('/api/v1/interviews/$sessionId/end');
      final data = resp.data as Map<String, dynamic>;
      return {
        'success': data['success'] ?? true,
        'score': data['score'],
        'feedback': data['feedback'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteInterview(int sessionId) async {
    try {
      await _api.dio.delete('/api/v1/interviews/$sessionId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getAvailableRoles() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/questions/roles');
      final data = resp.data as Map<String, dynamic>;
      return (data['roles'] as List? ?? []).cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInterviewHistory() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/history');
      final data = resp.data as Map<String, dynamic>;
      return (data['interviews'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getInterviewDetail(int sessionId) async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/$sessionId');
      final data = resp.data as Map<String, dynamic>;

      // Backend returns messages directly in root object
      // Each message has: role, content, is_voice, evaluation, timestamp
      final rawMessages = data['messages'] as List? ?? [];
      final messages =
          rawMessages.map((m) => m as Map<String, dynamic>).where((m) {
        final content = m['content']?.toString() ?? '';
        return content.isNotEmpty;
      }).toList();

      // Feedback can be at root or nested
      final feedback = data['feedback'] as Map<String, dynamic>?;

      return {
        'messages': messages,
        'feedback': feedback,
        'score': data['score'],
        'status': data['status'],
        'grade': data['grade'],
        'recommendation': data['recommendation'],
      };
    } catch (e) {
      return {'messages': [], 'feedback': null};
    }
  }

  Future<List<Map<String, dynamic>>> getAvatars() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/avatars');
      final data = resp.data as Map<String, dynamic>;
      return (data['avatars'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Start a real-time Anam video interview.
  /// Returns session_token for WebView initialization.
  Future<Map<String, dynamic>> startAnamInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    required String avatarId,
    int? goalId,
    int? resumeId,
  }) async {
    try {
      final resp = await _api.dio.post(
        '/api/v1/interviews/anam/session',
        data: {
          'job_role': jobRole,
          'difficulty': difficulty,
          'interview_type': interviewType,
          'language': language,
          'avatar_id': avatarId,
          if (goalId != null) 'goal_id': goalId,
          if (resumeId != null) 'resume_id': resumeId,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      return {
        'success': true,
        'interview_id': data['interview_id'],
        'session_token': data['session_token'],
        'avatar_name': data['avatar_name'],
        'avatar_language': data['avatar_language'],
        'avatar_id': data['avatar_id'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get available Anam avatars for the avatar picker.
  Future<List<Map<String, dynamic>>> getAnamAvatars() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/anam/avatars');
      final data = resp.data as Map<String, dynamic>;
      return (data['avatars'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
