// lib/features/interview/services/interview_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';

class InterviewService {
  final _api = ApiService();

  // ── Start interview ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    int? resumeId,
  }) async {
    try {
      final resp = await _api.dio.post(
        '/api/v1/interviews/',
        data: {
          'job_role': jobRole,
          'difficulty': difficulty,
          'interview_type': interviewType,
          'language': language,
          if (resumeId != null) 'resume_id': resumeId,
        },
      );
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

  // ── Text message ──────────────────────────────────────────────────────────
  // useAvatar=true  → POST /avatar-message  (returns video_url)
  // useAvatar=false → POST /message         (text only)

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

      final resp = await _api.dio.post(
        endpoint,
        data: useAvatar
            ? {
                'content': message,
                'use_avatar': true,
                'avatar_id': avatarId,
                'language': language,
                if (sourceUrl.isNotEmpty) 'source_url': sourceUrl,
              }
            : {'content': message},
      );

      final data = resp.data as Map<String, dynamic>;

      if (useAvatar) {
        return {
          'success': true,
          'response': data['response'],
          'interview_status': data['interview_status'],
          'score': data['score'],
          'feedback': data['feedback'],
        };
      } else {
        final aiMsg = data['ai_message'] as Map? ?? {};
        return {
          'success': true,
          'response': {'text': aiMsg['content'] ?? ''},
          'interview_status': data['interview_status'],
          'score': data['score'],
          'feedback': data['feedback'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Voice message ─────────────────────────────────────────────────────────
  // useAvatar=true  → POST /voice-avatar  (STT + AI + D-ID video, waits ~60-120s)
  // useAvatar=false → POST /voice         (STT + AI text only)

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

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: filename,
          contentType: DioMediaType('audio', 'webm'),
        ),
        'language': language,
        if (useAvatar) 'avatar_id': avatarId,
        if (useAvatar && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      });

      final resp = await _api.dio.post(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

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
        final aiMsg = data['ai_message'] as Map? ?? {};
        return {
          'success': true,
          'transcription': data['transcript'] ?? data['transcription'] ?? '',
          'response': {'text': aiMsg['content'] ?? ''},
          'interview_status': data['interview_status'],
          'score': data['score'],
          'feedback': data['feedback'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Async voice-avatar: returns text immediately, video arrives later ─────
  // POST /voice-avatar-async → {transcription, response: {text, clip_id, video_url: null}, ...}

  Future<Map<String, dynamic>> sendVoiceAsync(
    int sessionId,
    List<int> audioBytes,
    String filename, {
    String avatarId = 'professional_female',
    String sourceUrl = '',
    String language = 'en',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: filename,
          contentType: DioMediaType('audio', 'webm'),
        ),
        'language': language,
        'avatar_id': avatarId,
        if (sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      });

      final resp = await _api.dio.post(
        '/api/v1/interviews/$sessionId/voice-avatar-async',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = resp.data as Map<String, dynamic>;
      return {'success': true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Poll clip status until video_url is ready ─────────────────────────────
  // Emits: {'status': 'pending'} | {'status': 'done', 'video_url': '...'} |
  //        {'status': 'error'}   | {'status': 'timeout', 'video_url': null}

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
          options: Options(receiveTimeout: const Duration(seconds: 10)),
        );
        final data = resp.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';
        yield data;
        if (status == 'done' || status == 'error' || status == 'not_found') {
          return;
        }
      } catch (_) {
        // network hiccup — keep polling
      }
    }
    yield {'status': 'timeout', 'video_url': null};
  }

  // ── End interview ─────────────────────────────────────────────────────────

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

  // ── Delete interview ──────────────────────────────────────────────────────

  Future<bool> deleteInterview(int sessionId) async {
    try {
      await _api.dio.delete('/api/v1/interviews/$sessionId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Available roles ───────────────────────────────────────────────────────

  Future<List<String>> getAvailableRoles() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/questions/roles');
      final data = resp.data as Map<String, dynamic>;
      final list = data['roles'] as List? ?? [];
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInterviewHistory() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/history');
      final data = resp.data as Map<String, dynamic>;
      final list = data['interviews'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // ── Avatars list ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAvatars() async {
    try {
      final resp = await _api.dio.get('/api/v1/interviews/avatars');
      final data = resp.data as Map<String, dynamic>;
      final list = data['avatars'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
