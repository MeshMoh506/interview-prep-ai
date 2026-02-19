import 'package:dio/dio.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class AuthService {
  final _api = ApiService();

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.register,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
        },
      );
      
      if (response.statusCode == 201) {
        return {'success': true, 'user': response.data};
      }
      
      return {'success': false, 'message': 'Registration failed'};
    } on DioException catch (e) {
      final detail = e.response?.data['detail'];
      return {
        'success': false,
        'message': detail is String ? detail : 'Registration failed. Please try again.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.login,
        data: FormData.fromMap({
          'username': email.trim().toLowerCase(),
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final token = response.data['access_token'] as String;
        await _api.saveToken(token);
        return {'success': true, 'token': token};
      }
      
      return {'success': false, 'message': 'Invalid credentials'};
    } on DioException catch (e) {
      final detail = e.response?.data['detail'];
      return {
        'success': false,
        'message': detail is String ? detail : 'Login failed. Please try again.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    }
  }

  Future<Map<String, dynamic>> googleAuth({required String idToken}) async {
    try {
      final response = await _api.post(
        '${ApiConstants.authBase}/google',
        data: {'id_token': idToken},
      );
      
      if (response.statusCode == 200) {
        final token = response.data['access_token'] as String;
        await _api.saveToken(token);
        return {'success': true, 'token': token};
      }
      
      return {'success': false, 'message': 'Google authentication failed'};
    } on DioException catch (e) {
      final detail = e.response?.data['detail'];
      return {
        'success': false,
        'message': detail is String ? detail : 'Google login failed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _api.get('${ApiConstants.authBase}/me');
      
      if (response.statusCode == 200) {
        return {'success': true, 'user': response.data};
      }
      
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

  Future<void> logout() => _api.clearToken();

  Future<bool> isLoggedIn() => _api.hasToken();
}
