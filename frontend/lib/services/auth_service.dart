import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
      );
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'user': response.data,
        };
      }
      
      return {
        'success': false,
        'message': 'Registration failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Registration failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
  
  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.login,
        data: FormData.fromMap({
          'username': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        // Store token securely
        await _storage.write(key: 'access_token', value: token);
        
        return {
          'success': true,
          'token': token,
        };
      }
      
      return {
        'success': false,
        'message': 'Login failed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
  
  // Logout user
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }
  
  // Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConstants.userProfile);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': response.data,
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to get user profile',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Failed to get user profile',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
}
