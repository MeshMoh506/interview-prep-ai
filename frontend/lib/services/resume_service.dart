import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class ResumeService {
  final ApiService _apiService = ApiService();

  // ... [Keep all existing methods] ...

  /// Download resume as DOCX
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

  /// Download resume as PDF (NEW!)
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

  // Keep all other existing methods...
}
