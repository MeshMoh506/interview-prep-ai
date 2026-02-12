import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "api_service.dart";
import "../core/constants/api_constants.dart";

class AuthService {
  final ApiService _apiService = ApiService();

  // ✅ Web-compatible storage
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: "interview_prep_db",
      publicKey: "interview_prep_key",
    ),
  );

  // Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.register,
        data: {
          "email": email,
          "password": password,
          "full_name": fullName,
        },
      );
      if (response.statusCode == 201) {
        return {"success": true, "user": response.data};
      }
      return {"success": false, "message": "Registration failed"};
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data["detail"] ?? "Registration failed",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.login,
        data: FormData.fromMap({
          "username": email,
          "password": password,
        }),
      );
      if (response.statusCode == 200) {
        final token = response.data["access_token"];
        await _storage.write(key: "access_token", value: token);
        return {"success": true, "token": token};
      }
      return {"success": false, "message": "Login failed"};
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data["detail"] ?? "Login failed",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.delete(key: "access_token");
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: "access_token");
    return token != null && token.isNotEmpty;
  }

  // Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConstants.userProfile);
      if (response.statusCode == 200) {
        return {"success": true, "user": response.data};
      }
      return {"success": false, "message": "Failed to get profile"};
    } on DioException catch (e) {
      return {
        "success": false,
        "message": e.response?.data["detail"] ?? "Failed to get profile",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
