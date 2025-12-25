import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'task_state.dart';

/// GOD CLASS CUBIT - Traditional approach with ALL the problems.
///
/// PROBLEMS DEMONSTRATED:
/// 1. God Class - 400+ lines handling everything
/// 2. Race Conditions - No cancellation of previous requests
/// 3. Memory Leaks - Streams not properly disposed
/// 4. No Retry Logic - Fails permanently on first error
/// 5. No Caching - Always fetches from network
/// 6. Tightly Coupled - API calls mixed with state management
/// 7. Hard to Test - Too many responsibilities
/// 8. State Explosion - 20+ boolean flags
class TaskCubit extends Cubit<TaskState> {
  final MockApiService _api;

  // PROBLEM: These subscriptions are easy to forget to cancel
  StreamSubscription? _uploadSubscription;

  // PROBLEM: No way to cancel in-flight requests
  // When user clicks "Load" twice quickly, BOTH requests complete
  // and the second one may return BEFORE the first, causing stale data

  TaskCubit({MockApiService? api})
      : _api = api ?? MockApiService(),
        super(const TaskState()) {
    _api.initialize();
  }

  // ============ FETCH TASKS - RACE CONDITION DEMO ============

  /// Fetch all tasks.
  ///
  /// PROBLEM 1: No cancellation - if called twice quickly,
  /// both requests run and may complete in any order.
  ///
  /// PROBLEM 2: No caching - always hits network even for same data.
  ///
  /// PROBLEM 3: No retry - single failure = permanent error state.
  Future<void> fetchTasks() async {
    // User sees loading state
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      fetchCount: state.fetchCount + 1,
    ));

    try {
      // RACE CONDITION: If user clicks twice quickly,
      // Request A starts (takes 3s)
      // Request B starts (takes 1s)
      // Request B finishes -> UI shows B's data
      // Request A finishes -> UI shows A's data (STALE!)
      final tasks = await _api.fetchTasks();

      // PROBLEM: No check if this request is still relevant
      emit(state.copyWith(
        tasks: tasks,
        filteredTasks: _applyFilters(tasks),
        isLoading: false,
        lastFetchTime: DateTime.now(),
      ));
    } catch (e) {
      // PROBLEM: No retry, just fail
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  // ============ SEARCH - RACE CONDITION + NO DEBOUNCE ============

  /// Search tasks.
  ///
  /// PROBLEM 1: No debouncing - every keystroke triggers API call
  /// PROBLEM 2: No cancellation - typing "hello" triggers 5 requests
  /// PROBLEM 3: Results may arrive out of order
  Future<void> searchTasks(String query) async {
    emit(state.copyWith(
      searchQuery: query,
      isSearching: true,
      clearSearchError: true,
    ));

    if (query.isEmpty) {
      emit(state.copyWith(
        filteredTasks: _applyFilters(state.tasks),
        isSearching: false,
      ));
      return;
    }

    try {
      // Each keystroke fires this - "h", "he", "hel", "hell", "hello"
      // All 5 requests run simultaneously
      // Results arrive in random order: "hel" might arrive after "hello"
      final results = await _api.searchTasks(query);

      // STALE DATA BUG: This might be results for "hel" when user already typed "hello"
      emit(state.copyWith(
        filteredTasks: results,
        isSearching: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSearching: false,
        searchError: e.toString(),
      ));
    }
  }

  // ============ CREATE TASK - NO OPTIMISTIC UPDATE ============

  /// Create a new task.
  ///
  /// PROBLEM 1: No optimistic update - user waits for network
  /// PROBLEM 2: No offline support - fails completely if offline
  /// PROBLEM 3: No retry on failure
  Future<void> createTask(Task task) async {
    emit(state.copyWith(
      isCreating: true,
      clearCreateError: true,
    ));

    try {
      final createdTask = await _api.createTask(task);

      // Only update UI AFTER network succeeds - feels slow
      final updatedTasks = [...state.tasks, createdTask];
      emit(state.copyWith(
        tasks: updatedTasks,
        filteredTasks: _applyFilters(updatedTasks),
        isCreating: false,
      ));

      // PROBLEM: Categories count is now stale!
      // Must manually refresh categories too
      // In a real app, you'd forget this somewhere
    } catch (e) {
      emit(state.copyWith(
        isCreating: false,
        createError: e.toString(),
      ));
    }
  }

  // ============ DELETE TASK - RACE CONDITION ============

  /// Delete a task.
  ///
  /// PROBLEM: If user deletes multiple tasks quickly,
  /// the state updates may conflict.
  Future<void> deleteTask(String taskId) async {
    emit(state.copyWith(
      isDeleting: true,
      clearDeleteError: true,
    ));

    try {
      await _api.deleteTask(taskId);

      // Update local state
      final updatedTasks = state.tasks.where((t) => t.id != taskId).toList();
      emit(state.copyWith(
        tasks: updatedTasks,
        filteredTasks: _applyFilters(updatedTasks),
        isDeleting: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isDeleting: false,
        deleteError: e.toString(),
      ));
    }
  }

  // ============ UPDATE TASK ============

  /// Update an existing task.
  Future<void> updateTask(Task task) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final updatedTask = await _api.updateTask(task);
      final updatedTasks = state.tasks.map((t) {
        return t.id == updatedTask.id ? updatedTask : t;
      }).toList();

      emit(state.copyWith(
        tasks: updatedTasks,
        filteredTasks: _applyFilters(updatedTasks),
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // ============ UPLOAD - MEMORY LEAK DEMO ============

  /// Upload attachment with progress.
  ///
  /// PROBLEM 1: StreamSubscription may not be cancelled if user navigates away
  /// PROBLEM 2: No way to cancel upload in progress
  Future<void> uploadAttachment(String taskId, String fileName) async {
    emit(state.copyWith(
      isUploading: true,
      uploadProgress: 0,
      uploadingTaskId: taskId,
      clearUploadError: true,
    ));

    // MEMORY LEAK: If user navigates away, this subscription keeps running
    _uploadSubscription?.cancel();
    _uploadSubscription = _api.uploadAttachment(taskId, fileName).listen(
      (progress) {
        // PROBLEM: emit() may be called after cubit is closed
        emit(state.copyWith(uploadProgress: progress.progress));
      },
      onError: (e) {
        emit(state.copyWith(
          isUploading: false,
          uploadError: e.toString(),
          clearUploadingTaskId: true,
        ));
      },
      onDone: () {
        emit(state.copyWith(
          isUploading: false,
          uploadProgress: 1.0,
          clearUploadingTaskId: true,
        ));
      },
    );
  }

  // ============ FETCH CATEGORIES - SEPARATE STATE ============

  /// Fetch categories.
  ///
  /// PROBLEM: Must be called separately from fetchTasks()
  /// Easy to forget, leading to stale category counts.
  Future<void> fetchCategories() async {
    emit(state.copyWith(
      isLoadingCategories: true,
      clearCategoryError: true,
    ));

    try {
      final categories = await _api.fetchCategories();
      emit(state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCategories: false,
        categoryError: e.toString(),
      ));
    }
  }

  // ============ FETCH STATS - ANOTHER SEPARATE CALL ============

  /// Fetch dashboard stats.
  ///
  /// PROBLEM: Yet another thing to manually refresh.
  Future<void> fetchStats() async {
    emit(state.copyWith(
      isLoadingStats: true,
      clearStatsError: true,
    ));

    try {
      final stats = await _api.fetchDashboardStats();
      emit(state.copyWith(
        stats: stats,
        isLoadingStats: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingStats: false,
        statsError: e.toString(),
      ));
    }
  }

  // ============ FILTERS - LOCAL STATE MANAGEMENT ============

  void setStatusFilter(TaskStatus? status) {
    emit(state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
      filteredTasks: _applyFilters(state.tasks, statusOverride: status),
    ));
  }

  void setCategoryFilter(String? categoryId) {
    emit(state.copyWith(
      selectedCategoryId: categoryId,
      clearSelectedCategory: categoryId == null,
      filteredTasks: _applyFilters(state.tasks, categoryOverride: categoryId),
    ));
  }

  /// Apply all filters to tasks.
  List<Task> _applyFilters(
    List<Task> tasks, {
    TaskStatus? statusOverride,
    String? categoryOverride,
  }) {
    final status = statusOverride ?? state.statusFilter;
    final category = categoryOverride ?? state.selectedCategoryId;

    return tasks.where((task) {
      if (status != null && task.status != status) return false;
      if (category != null && task.categoryId != category) return false;
      return true;
    }).toList();
  }

  // ============ REFRESH ALL - MANUAL ORCHESTRATION ============

  /// Refresh everything.
  ///
  /// PROBLEM: Must manually call each method.
  /// Easy to miss one, especially as app grows.
  Future<void> refreshAll() async {
    // Fire all requests simultaneously
    await Future.wait([
      fetchTasks(),
      fetchCategories(),
      fetchStats(),
    ]);
  }

  // ============ CLEANUP - EASY TO FORGET ============

  @override
  Future<void> close() {
    // PROBLEM: Easy to forget this, causing memory leaks
    _uploadSubscription?.cancel();
    return super.close();
  }
}

