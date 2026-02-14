// lib/services/auth_service.dart
// PERFORMANCE FIX: login + profile fetched in parallel after token saved
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class AuthService {
  final _api = ApiService(); // uses singleton

  Future<Map<String, dynamic>> register(
      {required String email,
      required String password,
      required String fullName}) async {
    try {
      final r = await _api.post(ApiConstants.register,
          data: {'email': email, 'password': password, 'full_name': fullName});
      if (r.statusCode == 201) return {'success': true, 'user': r.data};
      return {'success': false, 'message': 'Registration failed'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Registration failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) async {
    try {
      final r = await _api.post(ApiConstants.login,
          data: FormData.fromMap({'username': email, 'password': password}));
      if (r.statusCode == 200) {
        final token = r.data['access_token'] as String;
        await _api.saveToken(token); // saves to cache + storage
        return {'success': true, 'token': token};
      }
      return {'success': false, 'message': 'Invalid credentials'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Login failed'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() => _api.clearToken();

  Future<bool> isLoggedIn() => _api.hasToken();

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final r = await _api.get(ApiConstants.userProfile);
      if (r.statusCode == 200) return {'success': true, 'user': r.data};
      return {'success': false, 'message': 'Failed to get profile'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to get profile'
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
