import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../models/dashboard_data.dart';

class DashboardService {
  final _api = ApiService();

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _api.get('/api/v1/dashboard/');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': DashboardData.fromJson(response.data),
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to load dashboard',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
