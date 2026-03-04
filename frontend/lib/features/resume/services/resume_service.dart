import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/resume_model.dart';

class ResumeService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> uploadResume(
      {required PlatformFile file, String? title}) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        if (title != null) 'title': title,
      });
      final r = await _apiService.post('${ApiConstants.resumes}/upload',
          data: formData);
      if (r.statusCode == 201) {
        return {'success': true, 'resume': Resume.fromJson(r.data)};
      }
      return {'success': false, 'message': 'Upload failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Upload failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getResumes() async {
    try {
      final r = await _apiService.get(ApiConstants.resumes);
      if (r.statusCode == 200) {
        return {
          'success': true,
          'resumes': (r.data as List).map((j) => Resume.fromJson(j)).toList()
        };
      }
      return {'success': false, 'message': 'Failed to fetch'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getResume(int id) async {
    try {
      final r = await _apiService.get('${ApiConstants.resumes}/$id');
      if (r.statusCode == 200) {
        return {'success': true, 'resume': Resume.fromJson(r.data)};
      }
      return {'success': false, 'message': 'Not found'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteResume(int id) async {
    try {
      final r = await _apiService.delete('${ApiConstants.resumes}/$id');
      if (r.statusCode == 200 || r.statusCode == 204) return {'success': true};
      return {'success': false, 'message': 'Delete failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> parseResume(int id) async {
    try {
      final r = await _apiService.post('${ApiConstants.resumes}/$id/parse-ai');
      if (r.statusCode == 200) {
        return {'success': true, 'resume': Resume.fromJson(r.data)};
      }
      return {'success': false, 'message': 'Parse failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Parse failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> analyzeResume(int id,
      {String? targetRole}) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/analyze',
        queryParameters:
            targetRole != null ? {'target_role': targetRole} : null,
      );
      if (r.statusCode == 200) {
        // FIX: backend returns analysis dict DIRECTLY, no 'analysis' wrapper
        final data = r.data as Map<String, dynamic>;
        return {
          'success': true,
          'analysis': data['analysis'] as Map<String, dynamic>? ?? data
        };
      }
      return {'success': false, 'message': 'Analysis failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkAts(int id) async {
    try {
      final r =
          await _apiService.post('${ApiConstants.resumes}/$id/check-format');
      if (r.statusCode == 200) {
        return {
          'success': true,
          'ats_analysis': r.data as Map<String, dynamic>
        };
      }
      return {'success': false, 'message': 'ATS check failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> matchJob(int id, String jobDescription) async {
    try {
      // FIX: send as JSON body not query param (backend expects request body)
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/match-job',
        data: {'job_description': jobDescription},
      );
      if (r.statusCode == 200) {
        final data = r.data as Map<String, dynamic>;
        final match = data['match_analysis'] ?? data['match_data'] ?? data;
        return {'success': true, 'match_data': match};
      }
      return {'success': false, 'message': 'Match failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateResume(int id, String templateId) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/generate',
        queryParameters: {'template_id': templateId},
      );
      if (r.statusCode == 200) return {'success': true, 'data': r.data};
      return {'success': false, 'message': 'Generate failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD THIS METHOD to ResumeService (after generateResume method)
  // ─────────────────────────────────────────────────────────────────────────

  /// Generate and immediately download resume with EDITED resume data.
  /// Sends the full edited resume_data as JSON body to the new endpoint.
  Future<Uint8List?> generateResumeWithData(
    int id,
    String templateId,
    Map<String, dynamic> resumeData,
  ) async {
    try {
      final r = await _apiService.dio.post<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/generate-with-data',
        data: {
          'template_id': templateId,
          'resume_data': resumeData,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> downloadResumeBytes(int id, String templateId) async {
    try {
      final r = await _apiService.dio.get<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/download',
        queryParameters: {'template_id': templateId},
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> downloadResumePdf(int id, String templateId) async {
    try {
      final r = await _apiService.dio.get<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/download-pdf',
        queryParameters: {'template_id': templateId},
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> rewriteAchievements(int id, List<String> bullets,
      {String? jobContext}) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/rewrite-achievements',
        data: bullets,
        queryParameters:
            jobContext != null ? {'job_context': jobContext} : null,
      );
      if (r.statusCode == 200) {
        return {'success': true, 'rewrites': r.data['rewrites']};
      }
      return {'success': false, 'message': 'Rewrite failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POWER FEATURES
  // ─────────────────────────────────────────────────────────────────────────

  /// Feature 1: AI rewrites entire resume to match a job description
  Future<Map<String, dynamic>?> tailorResume(
    int id, {
    required String jobDescription,
    required String targetRole,
  }) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/tailor',
        data: {
          'job_description': jobDescription,
          'target_role': targetRole,
        },
      );
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Tailoring failed'};
    } catch (e) {
      return null;
    }
  }

  /// Feature 2: Predict interview questions based on THIS specific resume
  Future<Map<String, dynamic>?> predictQuestions(
      int id, String targetRole) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/predict-questions',
        data: {'target_role': targetRole},
      );
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Prediction failed'};
    } catch (e) {
      return null;
    }
  }

  /// Feature 3: 6-dimension radar score
  Future<Map<String, dynamic>?> getRadarScore(
      int id, String? targetRole) async {
    try {
      final r = await _apiService.post(
        '${ApiConstants.resumes}/$id/radar-score',
        data: {'target_role': targetRole},
      );
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Radar score failed'};
    } catch (e) {
      return null;
    }
  }

  /// Feature 4: Generate 3 tone variants (aggressive / conservative / technical)
  Future<Map<String, dynamic>?> generateVariants(int id) async {
    try {
      final r = await _apiService.post('${ApiConstants.resumes}/$id/variants');
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {
        'error': e.response?.data['detail'] ?? 'Variant generation failed'
      };
    } catch (e) {
      return null;
    }
  }

  /// Download a specific variant DOCX (aggressive / conservative / technical)
  Future<Uint8List?> downloadVariantBytes(int id, String variant) async {
    try {
      final r = await _apiService.dio.get<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/variants/$variant/download',
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> buildAndDownloadDocx(
    Map<String, dynamic> resumeData,
    String templateId,
  ) async {
    // Uses resume ID 0 — the endpoint only needs user auth + data
    // Pass any valid resume ID the user has open, or use a sentinel
    // If you want ID-less: create a separate /build endpoint without ID param
    // For now, pass resumeData.containsKey('resume_id') if set, else -1
    final id = (resumeData['resume_id'] as int?) ?? 0;
    try {
      final r = await _apiService.dio.post<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/build-docx',
        data: {
          'template_id': templateId,
          'resume_data': resumeData,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Manual builder: generate PDF with user-filled data
  Future<Uint8List?> buildAndDownloadPdf(
    Map<String, dynamic> resumeData,
    String templateId,
  ) async {
    final id = (resumeData['resume_id'] as int?) ?? 0;
    try {
      final r = await _apiService.dio.post<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$id/build-pdf',
        data: {
          'template_id': templateId,
          'resume_data': resumeData,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── AI Builder ───────────────────────────────────────────────────────────

  /// AI builder: AI rewrites stored parsed resume → DOCX
  Future<Uint8List?> aiGenerateAndDownloadDocx({
    required int resumeId,
    required String targetRole,
    required String tone,
    required String templateId,
  }) async {
    try {
      final r = await _apiService.dio.post<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$resumeId/ai-build-docx',
        data: {
          'target_role': targetRole,
          'tone': tone,
          'template_id': templateId,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// AI builder: AI rewrites stored parsed resume → PDF
  Future<Uint8List?> aiGenerateAndDownloadPdf({
    required int resumeId,
    required String targetRole,
    required String tone,
    required String templateId,
  }) async {
    try {
      final r = await _apiService.dio.post<List<int>>(
        '${ApiConstants.baseUrl}/api/v1/resumes/$resumeId/ai-build-pdf',
        data: {
          'target_role': targetRole,
          'tone': tone,
          'template_id': templateId,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (r.statusCode == 200 && r.data != null) {
        return Uint8List.fromList(r.data!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
