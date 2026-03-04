import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dashboard_service.dart';
import '../models/dashboard_data.dart';

class DashboardState {
  final bool isLoading;
  final DashboardData? data;
  final String? error;

  const DashboardState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardData? data,
    String? error,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState()) {
    loadDashboard();
  }

  final _service = DashboardService();

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _service.getDashboard();
    
    if (result['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        data: result['data'],
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result['message'] ?? 'Failed to load dashboard',
      );
    }
  }

  Future<void> refresh() => loadDashboard();
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
