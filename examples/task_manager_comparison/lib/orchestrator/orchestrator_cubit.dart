import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import '../shared/shared.dart';
import '../shared/log_service.dart' as log_service;
import 'jobs.dart';

/// State for orchestrator approach - simpler!
class OrchestratorState {
  final List<Task> tasks;
  final List<Category> categories;
  final DashboardStats? stats;
  final bool isLoading;
  final bool isSearching;
  final String? error;
  final String searchQuery;
  final int fetchCount;
  final int completedFetches;
  final int cancelledFetches;

  const OrchestratorState({
    this.tasks = const [],
    this.categories = const [],
    this.stats,
    this.isLoading = false,
    this.isSearching = false,
    this.error,
    this.searchQuery = '',
    this.fetchCount = 0,
    this.completedFetches = 0,
    this.cancelledFetches = 0,
  });

  OrchestratorState copyWith({
    List<Task>? tasks,
    List<Category>? categories,
    DashboardStats? stats,
    bool? isLoading,
    bool? isSearching,
    String? error,
    String? searchQuery,
    int? fetchCount,
    int? completedFetches,
    int? cancelledFetches,
    bool clearError = false,
  }) {
    return OrchestratorState(
      tasks: tasks ?? this.tasks,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      fetchCount: fetchCount ?? this.fetchCount,
      completedFetches: completedFetches ?? this.completedFetches,
      cancelledFetches: cancelledFetches ?? this.cancelledFetches,
    );
  }
}

/// Orchestrator Cubit - WITH cancellation, NO race conditions!
class TaskOrchestrator extends OrchestratorCubit<OrchestratorState> {
  final LogService _log;

  // Cancellation tokens - KEY DIFFERENCE!
  CancellationToken? _fetchToken;
  CancellationToken? _searchToken;

  TaskOrchestrator(this._log) : super(const OrchestratorState());

  /// Fetch tasks - SOLUTION: Cancel previous request first!
  void fetchTasks() {
    // CANCEL previous fetch if still running
    _fetchToken?.cancel();
    _fetchToken = CancellationToken();

    final fetchNum = state.fetchCount + 1;

    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      fetchCount: fetchNum,
    ));

    _log.startTimer('orchestrator', 'fetchTasks #$fetchNum');

    dispatch(FetchTasksJob(
      cancellationToken: _fetchToken,
      retryPolicy: const RetryPolicy(maxRetries: 2),
    ));
  }

  /// Search tasks - SOLUTION: Cancel previous search!
  void searchTasks(String query) {
    // CANCEL previous search
    _searchToken?.cancel();
    _searchToken = CancellationToken();

    if (query.isEmpty) {
      emit(state.copyWith(searchQuery: '', isSearching: false));
      fetchTasks();
      return;
    }

    emit(state.copyWith(
      searchQuery: query,
      isSearching: true,
    ));

    _log.startTimer('orchestrator', 'search "$query"');

    dispatch(SearchTasksJob(query, cancellationToken: _searchToken));
  }

  /// Fetch categories.
  void fetchCategories() {
    _log.startTimer('orchestrator', 'fetchCategories');
    dispatch(FetchCategoriesJob());
  }

  /// Fetch stats.
  void fetchStats() {
    _log.startTimer('orchestrator', 'fetchStats');
    dispatch(FetchStatsJob());
  }

  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final data = event.data;

    if (data is List<Task>) {
      // Could be FetchTasks or SearchTasks
      if (state.isSearching) {
        _log.stopTimer('orchestrator', 'search "${state.searchQuery}"');
        emit(state.copyWith(
          tasks: data,
          isSearching: false,
        ));
      } else {
        _log.stopTimer('orchestrator', 'fetchTasks #${state.fetchCount}');
        emit(state.copyWith(
          tasks: data,
          isLoading: false,
          completedFetches: state.completedFetches + 1,
        ));
      }
    } else if (data is List<Category>) {
      _log.stopTimer('orchestrator', 'fetchCategories');
      emit(state.copyWith(categories: data));
    } else if (data is DashboardStats) {
      _log.stopTimer('orchestrator', 'fetchStats');
      emit(state.copyWith(stats: data));
    }
  }

  @override
  void onActiveFailure(JobFailureEvent event) {
    if (event.error is CancelledException) {
      // Intentional cancellation - not an error!
      return;
    }

    _log.log('orchestrator', 'Error', details: event.error.toString(), level: log_service.LogLevel.error);
    emit(state.copyWith(
      isLoading: false,
      isSearching: false,
      error: event.error.toString(),
    ));
  }

  @override
  void onActiveCancelled(JobCancelledEvent event) {
    // Determine what was cancelled based on current state
    if (state.isSearching) {
      _log.logCancellation('orchestrator', 'search "${state.searchQuery}"');
    } else if (state.isLoading) {
      _log.logCancellation('orchestrator', 'fetchTasks #${state.fetchCount}');
    }

    emit(state.copyWith(
      isLoading: false,
      isSearching: false,
      cancelledFetches: state.cancelledFetches + 1,
    ));
  }

  /// Reset state.
  void reset() {
    _fetchToken?.cancel();
    _searchToken?.cancel();
    _fetchToken = null;
    _searchToken = null;
    emit(const OrchestratorState());
  }

  @override
  Future<void> close() {
    _fetchToken?.cancel();
    _searchToken?.cancel();
    return super.close();
  }
}
