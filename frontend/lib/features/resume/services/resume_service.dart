// lib/features/resume/services/resume_service.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_service.dart';
import '../models/resume_model.dart';
import 'package:flutter/foundation.dart';

class ResumeService {
  final ApiService _api = ApiService();

  // Base path — trailing slash prevents 307 redirect
  static const String _base = '/api/v1/resumes/';

  Future<Map<String, dynamic>> uploadResume(
      {required PlatformFile file, String? title}) async {
    try {
      debugPrint('=== UPLOAD START ===');
      debugPrint('file.name: ${file.name}');
      debugPrint('file.path: ${file.path}');
      debugPrint('file.bytes null: ${file.bytes == null}');

      MultipartFile multipartFile;
      if (file.bytes != null) {
        multipartFile =
            MultipartFile.fromBytes(file.bytes!, filename: file.name);
      } else if (file.path != null) {
        multipartFile =
            await MultipartFile.fromFile(file.path!, filename: file.name);
      } else {
        return {'success': false, 'message': 'Could not read file'};
      }

      debugPrint('=== SENDING REQUEST ===');
      final formData = FormData.fromMap({
        'file': multipartFile,
        if (title != null) 'title': title,
      });

      final r = await _api.dio.post(
        '${_base}upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      debugPrint('=== RESPONSE ===');
      debugPrint('status: ${r.statusCode}');
      debugPrint('data type: ${r.data.runtimeType}');
      debugPrint('data: ${r.data}');

      if (r.statusCode == 201) {
        return {'success': true, 'resume': null};
      }
      return {'success': false, 'message': 'Upload failed: ${r.statusCode}'};
    } on DioException catch (e) {
      debugPrint('=== DIO ERROR ===');
      debugPrint('type: ${e.type}');
      debugPrint('response: ${e.response?.data}');
      debugPrint('message: ${e.message}');
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : data?.toString();
      return {
        'success': false,
        'message': detail ?? e.message ?? 'Upload failed'
      };
    } catch (e, st) {
      debugPrint('=== CATCH ERROR ===');
      debugPrint('error: $e');
      debugPrint('stacktrace: $st');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getResumes() async {
    try {
      final r = await _api.get(_base);
      if (r.statusCode == 200) {
        // Handle both List response and Map with 'resumes' key
        List<dynamic> rawList;
        if (r.data is List) {
          rawList = r.data as List;
        } else if (r.data is Map && r.data['resumes'] != null) {
          rawList = r.data['resumes'] as List;
        } else {
          rawList = [];
        }
        return {
          'success': true,
          'resumes': rawList
              .map((j) => Resume.fromJson(j as Map<String, dynamic>))
              .toList()
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
      final r = await _api.get('$_base$id');
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
      final r = await _api.delete('$_base$id');
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
      final r = await _api.post('$_base$id/parse-ai');
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
      final r = await _api.post(
        '$_base$id/analyze',
        queryParameters:
            targetRole != null ? {'target_role': targetRole} : null,
      );
      if (r.statusCode == 200) {
        final data = r.data as Map<String, dynamic>;
        return {'success': true, 'analysis': data['analysis'] ?? data};
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
      final r = await _api.post('$_base$id/check-format');
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
      final r = await _api.post(
        '$_base$id/match-job',
        data: {'job_description': jobDescription},
      );
      if (r.statusCode == 200) {
        final data = r.data as Map<String, dynamic>;
        return {'success': true, 'match_data': data['match_analysis'] ?? data};
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
      final r = await _api.post(
        '$_base$id/generate',
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

  Future<Uint8List?> generateResumeWithData(
      int id, String templateId, Map<String, dynamic> resumeData) async {
    try {
      final r = await _api.dio.post<List<int>>(
        '$_base$id/generate-with-data',
        data: {'template_id': templateId, 'resume_data': resumeData},
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
      final r = await _api.dio.get<List<int>>(
        '$_base$id/download',
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
      final r = await _api.dio.get<List<int>>(
        '$_base$id/download-pdf',
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
      final r = await _api.post(
        '$_base$id/rewrite-achievements',
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

  Future<Map<String, dynamic>?> tailorResume(int id,
      {required String jobDescription, required String targetRole}) async {
    try {
      final r = await _api.post('$_base$id/tailor',
          data: {'job_description': jobDescription, 'target_role': targetRole});
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Tailoring failed'};
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> predictQuestions(
      int id, String targetRole) async {
    try {
      final r = await _api.post('$_base$id/predict-questions',
          data: {'target_role': targetRole});
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Prediction failed'};
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRadarScore(
      int id, String? targetRole) async {
    try {
      final r = await _api
          .post('$_base$id/radar-score', data: {'target_role': targetRole});
      if (r.statusCode == 200) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      return {'error': e.response?.data['detail'] ?? 'Radar score failed'};
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateVariants(int id) async {
    try {
      final r = await _api.post('$_base$id/variants');
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

  Future<Uint8List?> downloadVariantBytes(int id, String variant) async {
    try {
      final r = await _api.dio.get<List<int>>(
        '$_base$id/variants/$variant/download',
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
      Map<String, dynamic> resumeData, String templateId) async {
    final id = (resumeData['resume_id'] as int?) ?? 0;
    try {
      final r = await _api.dio.post<List<int>>(
        '$_base$id/build-docx',
        data: {'template_id': templateId, 'resume_data': resumeData},
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

  Future<Uint8List?> buildAndDownloadPdf(
      Map<String, dynamic> resumeData, String templateId) async {
    final id = (resumeData['resume_id'] as int?) ?? 0;
    try {
      final r = await _api.dio.post<List<int>>(
        '$_base$id/build-pdf',
        data: {'template_id': templateId, 'resume_data': resumeData},
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

  Future<Uint8List?> aiGenerateAndDownloadDocx({
    required int resumeId,
    required String targetRole,
    required String tone,
    required String templateId,
  }) async {
    try {
      final r = await _api.dio.post<List<int>>(
        '$_base$resumeId/ai-build-docx',
        data: {
          'target_role': targetRole,
          'tone': tone,
          'template_id': templateId
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

  Future<Uint8List?> aiGenerateAndDownloadPdf({
    required int resumeId,
    required String targetRole,
    required String tone,
    required String templateId,
  }) async {
    try {
      final r = await _api.dio.post<List<int>>(
        '$_base$resumeId/ai-build-pdf',
        data: {
          'target_role': targetRole,
          'tone': tone,
          'template_id': templateId
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
