// lib/features/profile/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────
class ProfileState {
  final bool isLoading;
  final bool isSaving;
  final UserProfile? profile;
  final String? error;

  const ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.profile,
    this.error,
  });

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    UserProfile? profile,
    String? error,
    bool clearError = false,
  }) =>
      ProfileState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        profile: profile ?? this.profile,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const ProfileState());

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final profile = await _service.getProfile();
    if (!mounted) return;
    if (profile != null) {
      state = state.copyWith(isLoading: false, profile: profile);
    } else {
      state = state.copyWith(isLoading: false, error: 'Failed to load profile');
    }
  }

  /// General tab — updates name, jobTitle, bio
  Future<void> updateProfile({
    required String fullName,
    required String jobTitle,
    required String bio,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    final updated = await _service.updateProfile({
      'full_name': fullName,
      'job_title': jobTitle,
      'bio': bio,
    });
    if (!mounted) return;
    state = state.copyWith(
      isSaving: false,
      profile: updated ?? state.profile,
    );
  }

  /// Settings tab — email notifications, language etc.
  Future<void> updateSettings({
    required bool emailNotifications,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    final updated = await _service.updatePreferences({
      'email_notifications': emailNotifications,
    });
    if (!mounted) return;
    state = state.copyWith(
      isSaving: false,
      profile: updated ?? state.profile,
    );
  }

  /// Security tab — change password (no current password required by API)
  Future<bool> updatePassword({required String newPassword}) async {
    state = state.copyWith(isSaving: true, clearError: true);
    // API requires current_password — pass empty string if not collected
    // (adjust if backend enforces it)
    final ok = await _service.changePassword(
      currentPassword: '',
      newPassword: newPassword,
    );
    if (!mounted) return false;
    state = state.copyWith(isSaving: false);
    return ok;
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isSaving: true);
    final ok = await _service.deleteAccount();
    if (!mounted) return false;
    state = state.copyWith(isSaving: false);
    return ok;
  }

  void reset() => state = const ProfileState();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ProfileService()),
);
