// lib/features/roadmap/providers/roadmap_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roadmap_model.dart';
import '../services/roadmap_service.dart';
import '../../../services/api_service.dart';

// ── List Provider ─────────────────────────────────────────────────────────────
final roadmapListProvider =
    StateNotifierProvider<RoadmapListNotifier, RoadmapListState>((ref) {
  return RoadmapListNotifier(RoadmapService(ApiService()));
});

class RoadmapListState {
  final bool isLoading;
  final List<Roadmap> roadmaps;
  final String? error;

  const RoadmapListState({
    this.isLoading = false,
    this.roadmaps = const [],
    this.error,
  });

  RoadmapListState copyWith({
    bool? isLoading,
    List<Roadmap>? roadmaps,
    String? error,
    bool clearError = false,
  }) =>
      RoadmapListState(
        isLoading: isLoading ?? this.isLoading,
        roadmaps: roadmaps ?? this.roadmaps,
        error: clearError ? null : (error ?? this.error),
      );
}

class RoadmapListNotifier extends StateNotifier<RoadmapListState> {
  final RoadmapService _svc;

  RoadmapListNotifier(this._svc) : super(const RoadmapListState()) {
    Future.microtask(() => load());
  }

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final roadmaps = await _svc.getRoadmaps();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, roadmaps: roadmaps);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> generate({
    required String targetRole,
    required String difficulty,
    int? resumeId,
    String pathType = 'balanced',
    bool includeCapstone = true,
    int hoursPerWeek = 10,
    int targetWeeks = 8,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final roadmap = await _svc.generateRoadmap(
        targetRole: targetRole,
        difficulty: difficulty,
        resumeId: resumeId,
        pathType: pathType,
        includeCapstone: includeCapstone,
        hoursPerWeek: hoursPerWeek,
        targetWeeks: targetWeeks,
      );
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        roadmaps: [...state.roadmaps, roadmap],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _svc.deleteRoadmap(id);
      if (!mounted) return;
      state = state.copyWith(
        roadmaps: state.roadmaps.where((r) => r.id != id).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }
}

// ── Detail Provider (per roadmap) ─────────────────────────────────────────────
final roadmapDetailProvider = StateNotifierProvider.family<
    RoadmapDetailNotifier, RoadmapDetailState, int>((ref, id) {
  return RoadmapDetailNotifier(RoadmapService(ApiService()));
});

class RoadmapDetailState {
  final bool isLoading;
  final Roadmap? roadmap;
  final String? error;

  const RoadmapDetailState({
    this.isLoading = false,
    this.roadmap,
    this.error,
  });

  RoadmapDetailState copyWith({
    bool? isLoading,
    Roadmap? roadmap,
    String? error,
  }) =>
      RoadmapDetailState(
        isLoading: isLoading ?? this.isLoading,
        roadmap: roadmap ?? this.roadmap,
        error: error ?? this.error,
      );
}

class RoadmapDetailNotifier extends StateNotifier<RoadmapDetailState> {
  final RoadmapService _svc;

  RoadmapDetailNotifier(this._svc) : super(const RoadmapDetailState());

  Future<void> load(int id) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final roadmap = await _svc.getRoadmap(id);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, roadmap: roadmap);
    } catch (e) {
      if (!mounted) return;
      state = RoadmapDetailState(isLoading: false, error: e.toString());
    }
  }
}
