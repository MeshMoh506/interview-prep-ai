// lib/features/resume/providers/resume_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/resume_service.dart';
import '../models/resume_model.dart';

final resumeServiceProvider = Provider<ResumeService>((ref) => ResumeService());

class ResumeState {
  final bool isLoading;
  final bool isUploading;
  final List<Resume> resumes;
  final Resume? selectedResume;
  final String? error;

  const ResumeState({
    this.isLoading = false,
    this.isUploading = false,
    this.resumes = const [],
    this.selectedResume,
    this.error,
  });

  factory ResumeState.initial() => const ResumeState();

  ResumeState copyWith({
    bool? isLoading,
    bool? isUploading,
    List<Resume>? resumes,
    Resume? selectedResume,
    bool clearSelected = false,
    String? error,
    bool clearError = false,
  }) {
    return ResumeState(
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      resumes: resumes ?? this.resumes,
      selectedResume:
          clearSelected ? null : (selectedResume ?? this.selectedResume),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ResumeNotifier extends StateNotifier<ResumeState> {
  final ResumeService _s;

  ResumeNotifier(this._s) : super(ResumeState.initial()) {
    // Use microtask to avoid calling async code during provider construction
    Future.microtask(() => loadResumes());
  }

  Future<void> loadResumes() async {
    if (!mounted) return; // ← guard #1
    state = state.copyWith(isLoading: true, clearError: true);

    final r = await _s.getResumes();

    if (!mounted) return; // ← guard #2: check after await

    if (r['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        resumes: r['resumes'] as List<Resume>,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: r['message']?.toString(),
      );
    }
  }

  Future<bool> uploadResume(PlatformFile file, {String? title}) async {
    if (!mounted) return false;
    state = state.copyWith(isUploading: true, clearError: true);

    final r = await _s.uploadResume(file: file, title: title);

    if (!mounted) return false;
    state = state.copyWith(isUploading: false);

    if (r['success'] == true) {
      await loadResumes();
      return true;
    }
    if (mounted) state = state.copyWith(error: r['message']?.toString());
    return false;
  }

  Future<bool> deleteResume(int id) async {
    if (!mounted) return false;
    final r = await _s.deleteResume(id);
    if (!mounted) return false;

    if (r['success'] == true) {
      state = state.copyWith(
        resumes: state.resumes.where((x) => x.id != id).toList(),
      );
      return true;
    }
    state = state.copyWith(error: r['message']?.toString());
    return false;
  }

  Future<void> selectResume(int id) async {
    if (!mounted) return;
    final cached = state.resumes.where((x) => x.id == id).firstOrNull;
    if (cached != null && mounted) {
      state = state.copyWith(selectedResume: cached);
    }

    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    final r = await _s.getResume(id);

    if (!mounted) return;
    state = state.copyWith(isLoading: false);

    if (r['success'] == true) {
      state = state.copyWith(selectedResume: r['resume'] as Resume);
    } else {
      state = state.copyWith(error: r['message']?.toString());
    }
  }

  Future<bool> parseResume(int id) async {
    if (!mounted) return false;
    final r = await _s.parseResume(id);
    if (!mounted) return false;

    if (r['success'] == true) {
      final u = r['resume'] as Resume;
      state = state.copyWith(
        selectedResume: u,
        resumes: state.resumes.map((x) => x.id == id ? u : x).toList(),
      );
      return true;
    }
    state = state.copyWith(error: r['message']?.toString());
    return false;
  }

  Future<Map<String, dynamic>?> analyzeResume(int id,
      {String? targetRole}) async {
    if (!mounted) return null;
    final r = await _s.analyzeResume(id, targetRole: targetRole);
    if (!mounted) return null;

    if (r['success'] == true) return r['analysis'] as Map<String, dynamic>?;
    if (mounted) state = state.copyWith(error: r['message']?.toString());
    return null;
  }

  Future<Map<String, dynamic>?> checkAts(int id) async {
    if (!mounted) return null;
    final r = await _s.checkAts(id);
    if (!mounted) return null;

    if (r['success'] == true) return r['ats_analysis'] as Map<String, dynamic>?;
    if (mounted) state = state.copyWith(error: r['message']?.toString());
    return null;
  }

  Future<Map<String, dynamic>?> matchJob(int id, String jd) async {
    if (!mounted) return null;
    final r = await _s.matchJob(id, jd);
    if (!mounted) return null;

    if (r['success'] == true) return r['match_data'] as Map<String, dynamic>?;
    if (mounted) state = state.copyWith(error: r['message']?.toString());
    return null;
  }

  Future<Map<String, dynamic>?> generateResume(int id, String tpl) async {
    if (!mounted) return null;
    final r = await _s.generateResume(id, tpl);
    if (!mounted) return null;

    if (r['success'] == true) return r['data'] as Map<String, dynamic>?;
    if (mounted) state = state.copyWith(error: r['message']?.toString());
    return null;
  }

  void clearSelected() {
    if (mounted) state = state.copyWith(clearSelected: true);
  }
}

final resumeProvider =
    StateNotifierProvider<ResumeNotifier, ResumeState>((ref) {
  return ResumeNotifier(ref.watch(resumeServiceProvider));
});

final resumesProvider = FutureProvider<List<Resume>>((ref) async {
  final state = ref.watch(resumeProvider);
  return state.resumes;
});
