import 'package:flutter_bloc/flutter_bloc.dart';
import '../shared/shared.dart';

/// Traditional state - has many boolean flags.
class TraditionalState {
  final List<Task> tasks;
  final List<Category> categories;
  final DashboardStats? stats;
  final bool isLoading;
  final bool isSearching;
  final String? error;
  final String searchQuery;
  final int fetchCount;
  final int completedFetches;

  const TraditionalState({
    this.tasks = const [],
    this.categories = const [],
    this.stats,
    this.isLoading = false,
    this.isSearching = false,
    this.error,
    this.searchQuery = '',
    this.fetchCount = 0,
    this.completedFetches = 0,
  });

  TraditionalState copyWith({
    List<Task>? tasks,
    List<Category>? categories,
    DashboardStats? stats,
    bool? isLoading,
    bool? isSearching,
    String? error,
    String? searchQuery,
    int? fetchCount,
    int? completedFetches,
    bool clearError = false,
  }) {
    return TraditionalState(
      tasks: tasks ?? this.tasks,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      fetchCount: fetchCount ?? this.fetchCount,
      completedFetches: completedFetches ?? this.completedFetches,
    );
  }
}

/// Traditional Cubit - NO cancellation, has race conditions.
class TraditionalCubit extends Cubit<TraditionalState> {
  final MockApi _api;
  final LogService _log;

  // Track which request number we're on to detect race conditions
  int _currentFetchRequest = 0;
  int _currentSearchRequest = 0;

  TraditionalCubit(this._api, this._log) : super(const TraditionalState());

  /// Fetch tasks - PROBLEM: No cancellation of previous requests!
  Future<void> fetchTasks() async {
    final thisRequest = ++_currentFetchRequest;
    final fetchNum = state.fetchCount + 1;

    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      fetchCount: fetchNum,
    ));

    _log.startTimer('traditional', 'fetchTasks #$fetchNum');

    try {
      final (tasks, delayMs, isStale) = await _api.fetchTasks();

      // Check if a newer request was started while we were waiting
      if (thisRequest != _currentFetchRequest) {
        // RACE CONDITION! But traditional approach has no way to prevent this.
        _log.logRaceCondition(
          'traditional',
          'Request #$thisRequest completed but #$_currentFetchRequest is current (delay: ${delayMs}ms)',
        );
      }

      // Traditional approach ALWAYS updates state, even if stale!
      _log.stopTimer('traditional', 'fetchTasks #$fetchNum');

      emit(state.copyWith(
        tasks: tasks,
        isLoading: false,
        completedFetches: state.completedFetches + 1,
      ));
    } catch (e) {
      _log.stopTimer('traditional', 'fetchTasks #$fetchNum', success: false);
      _log.log('traditional', 'Error', details: e.toString(), level: LogLevel.error);
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// Search tasks - PROBLEM: Every keystroke fires a request!
  Future<void> searchTasks(String query) async {
    if (query.isEmpty) {
      emit(state.copyWith(searchQuery: '', isSearching: false));
      fetchTasks();
      return;
    }

    final thisRequest = ++_currentSearchRequest;

    emit(state.copyWith(
      searchQuery: query,
      isSearching: true,
    ));

    _log.startTimer('traditional', 'search "$query"');

    try {
      final (results, delayMs, isStale, searchedQuery) = await _api.searchTasks(query);

      // Check for race condition
      if (thisRequest != _currentSearchRequest) {
        _log.logRaceCondition(
          'traditional',
          'Search "$searchedQuery" returned but user already typed something else (delay: ${delayMs}ms)',
        );
      }

      _log.stopTimer('traditional', 'search "$query"');

      // Always update - even if stale results!
      emit(state.copyWith(
        tasks: results,
        isSearching: false,
      ));
    } catch (e) {
      _log.stopTimer('traditional', 'search "$query"', success: false);
      emit(state.copyWith(isSearching: false, error: e.toString()));
    }
  }

  /// Fetch categories.
  Future<void> fetchCategories() async {
    _log.startTimer('traditional', 'fetchCategories');
    try {
      final categories = await _api.fetchCategories();
      _log.stopTimer('traditional', 'fetchCategories');
      emit(state.copyWith(categories: categories));
    } catch (e) {
      _log.stopTimer('traditional', 'fetchCategories', success: false);
    }
  }

  /// Fetch stats.
  Future<void> fetchStats() async {
    _log.startTimer('traditional', 'fetchStats');
    try {
      final stats = await _api.fetchStats();
      _log.stopTimer('traditional', 'fetchStats');
      emit(state.copyWith(stats: stats));
    } catch (e) {
      _log.stopTimer('traditional', 'fetchStats', success: false);
    }
  }

  /// Reset state.
  void reset() {
    _currentFetchRequest = 0;
    _currentSearchRequest = 0;
    emit(const TraditionalState());
  }
}
