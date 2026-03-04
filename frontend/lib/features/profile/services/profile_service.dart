// lib/features/profile/services/profile_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';
import '../models/profile_model.dart';

/// Result wrapper for changePassword so the UI can show the exact backend error
class PasswordChangeResult {
  final bool success;
  final String? error;
  const PasswordChangeResult({required this.success, this.error});
}

class ProfileService {
  final _api = ApiService();

  Future<UserProfile?> getProfile() async {
    try {
      final r = await _api.get('/api/v1/users/me');
      return UserProfile.fromJson(r.data);
    } catch (e) {
      debugPrint('getProfile error: $e');
      return null;
    }
  }

  Future<UserProfile?> updateProfile(Map<String, dynamic> data) async {
    try {
      final r = await _api.put('/api/v1/users/me', data: data);
      return UserProfile.fromJson(r.data);
    } catch (e) {
      debugPrint('updateProfile error: $e');
      return null;
    }
  }

  Future<UserProfile?> updatePreferences(Map<String, dynamic> data) async {
    try {
      final r = await _api.put('/api/v1/users/me/preferences', data: data);
      return UserProfile.fromJson(r.data);
    } catch (e) {
      debugPrint('updatePreferences error: $e');
      return null;
    }
  }

  /// FIX: Returns PasswordChangeResult with exact backend error message
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post('/api/v1/users/me/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      return const PasswordChangeResult(success: true);
    } on DioException catch (e) {
      // Extract exact detail message from backend (e.g. "Current password is incorrect")
      final detail =
          e.response?.data?['detail']?.toString() ?? 'Password update failed';
      debugPrint('changePassword error: $detail');
      return PasswordChangeResult(success: false, error: detail);
    } catch (e) {
      debugPrint('changePassword error: $e');
      return PasswordChangeResult(success: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final r = await _api.get('/api/v1/users/me/stats');
      return r.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('getStats error: $e');
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _api.delete('/api/v1/users/me');
      return true;
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return false;
    }
  }
}
