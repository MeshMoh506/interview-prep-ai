// lib/features/dashboard/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../models/dashboard_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class DashboardService {
  final ApiService _api = ApiService();

  Future<DashboardData?> fetchDashboard() async {
    try {
      final r = await _api.get('/api/v1/dashboard/');
      if (r.statusCode == 200) return DashboardData.fromJson(r.data);
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────
class DashboardState {
  final bool isLoading;
  final DashboardData? data;
  final String? error;
  final DateTime? lastLoaded;

  const DashboardState({
    this.isLoading = false,
    this.data,
    this.error,
    this.lastLoaded,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardData? data,
    String? error,
    bool clearError = false,
    DateTime? lastLoaded,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        data: data ?? this.data,
        error: clearError ? null : (error ?? this.error),
        lastLoaded: lastLoaded ?? this.lastLoaded,
      );

  bool get hasData => data != null;
  bool get isStale =>
      lastLoaded == null ||
      DateTime.now().difference(lastLoaded!) > const Duration(seconds: 60);
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardService _service;

  DashboardNotifier(this._service) : super(const DashboardState()) {
    load();
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading) return;
    if (!force && !state.isStale && state.hasData) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final data = await _service.fetchDashboard();

    if (!mounted) return;

    if (data != null) {
      state = state.copyWith(
        isLoading: false,
        data: data,
        lastLoaded: DateTime.now(),
        clearError: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard. Pull to refresh.',
      );
    }
  }

  Future<void> refresh() => load(force: true);

  void reset() => state = const DashboardState();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(DashboardService()),
);
