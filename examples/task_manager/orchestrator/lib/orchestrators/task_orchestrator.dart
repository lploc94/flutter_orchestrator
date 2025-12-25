import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import 'package:shared/shared.dart';
import '../jobs/task_jobs.dart';
import 'task_state.dart';

/// Task Orchestrator using OrchestratorCubit.
///
/// KEY DIFFERENCES FROM TRADITIONAL CUBIT:
/// 1. Automatic cancellation of previous requests (no race conditions)
/// 2. Built-in retry support
/// 3. Clean separation - only manages UI state, no business logic
/// 4. Events are automatically routed (Active/Passive)
/// 5. Easy to test - just verify jobs are dispatched correctly
class TaskOrchestrator extends OrchestratorCubit<TaskState> {
  // Track cancellation tokens for cancellable operations
  CancellationToken? _fetchToken;
  CancellationToken? _searchToken;

  TaskOrchestrator() : super(const TaskState());

  // ============ FETCH TASKS - WITH CANCELLATION ============

  /// Fetch all tasks with automatic cancellation of previous request.
  ///
  /// SOLUTION TO RACE CONDITION:
  /// - Cancel any in-flight fetch request before starting new one
  /// - Only the latest request's result will be processed
  void fetchTasks({bool forceRefresh = false}) {
    // Cancel previous fetch if still running
    _fetchToken?.cancel();
    _fetchToken = CancellationToken();

    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      fetchCount: state.fetchCount + 1,
    ));

    dispatch(FetchTasksJob(
      forceRefresh: forceRefresh,
      cancellationToken: _fetchToken,
      timeout: const Duration(seconds: 10),
      retryPolicy: const RetryPolicy(maxRetries: 2),
    ));
  }

  // ============ SEARCH - WITH CANCELLATION ============

  /// Search tasks with automatic cancellation.
  ///
  /// SOLUTION TO SEARCH RACE CONDITION:
  /// - Each keystroke cancels the previous search
  /// - Only shows results for the latest query
  void searchTasks(String query) {
    // Cancel previous search
    _searchToken?.cancel();
    _searchToken = CancellationToken();

    emit(state.copyWith(
      searchQuery: query,
      isSearching: true,
    ));

    dispatch(SearchTasksJob(
      query,
      cancellationToken: _searchToken,
      timeout: const Duration(seconds: 5),
    ));
  }

  // ============ CREATE TASK ============

  void createTask({
    required String title,
    String description = '',
    required String categoryId,
  }) {
    emit(state.copyWith(isCreating: true, clearError: true));

    dispatch(CreateTaskJob(
      title: title,
      description: description,
      categoryId: categoryId,
      retryPolicy: const RetryPolicy(maxRetries: 3),
    ));
  }

  // ============ UPDATE TASK ============

  void updateTask(String taskId, {String? status, String? priority}) {
    dispatch(UpdateTaskJob(
      taskId: taskId,
      status: status,
      priority: priority,
    ));
  }

  // ============ DELETE TASK ============

  void deleteTask(String taskId) {
    dispatch(DeleteTaskJob(taskId));
  }

  // ============ FETCH CATEGORIES ============

  void fetchCategories() {
    dispatch(FetchCategoriesJob());
  }

  // ============ FETCH STATS ============

  void fetchStats() {
    dispatch(FetchStatsJob());
  }

  // ============ LOCAL FILTERS ============

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

  List<Task> _applyFilters(List<Task> tasks, {TaskStatus? statusOverride, String? categoryOverride}) {
    final status = statusOverride ?? state.statusFilter;
    final category = categoryOverride ?? state.selectedCategoryId;
    return tasks.where((task) {
      if (status != null && task.status != status) return false;
      if (category != null && task.categoryId != category) return false;
      return true;
    }).toList();
  }

  // ============ REFRESH ALL ============

  void refreshAll() {
    fetchTasks(forceRefresh: true);
    fetchCategories();
    fetchStats();
  }

  // ============ EVENT HANDLERS - ACTIVE EVENTS ============

  /// Handle successful job completion.
  /// These are "Active" events - jobs that THIS orchestrator dispatched.
  @override
  void onActiveSuccess(JobSuccessEvent event) {
    final data = event.data;

    if (data is List<Task>) {
      // Handle FetchTasksJob or SearchTasksJob success
      emit(state.copyWith(
        tasks: data,
        filteredTasks: _applyFilters(data),
        isLoading: false,
        isSearching: false,
        lastFetchTime: DateTime.now(),
      ));
    } else if (data is Task) {
      // Handle CreateTaskJob or UpdateTaskJob success
      final updatedTasks = _updateTaskInList(state.tasks, data);
      emit(state.copyWith(
        tasks: updatedTasks,
        filteredTasks: _applyFilters(updatedTasks),
        isCreating: false,
      ));
      // Refresh related data
      fetchCategories();
      fetchStats();
    } else if (data is List<Category>) {
      emit(state.copyWith(categories: data));
    } else if (data is DashboardStats) {
      emit(state.copyWith(stats: data));
    } else if (data == null) {
      // Handle DeleteTaskJob success (returns void)
      // Refresh the task list
      fetchTasks();
      fetchCategories();
      fetchStats();
    }
  }

  /// Handle job failure.
  @override
  void onActiveFailure(JobFailureEvent event) {
    // Ignore cancelled jobs - they're intentional
    if (event.error is CancelledException) {
      emit(state.copyWith(isLoading: false, isSearching: false, isCreating: false));
      return;
    }

    emit(state.copyWith(
      isLoading: false,
      isSearching: false,
      isCreating: false,
      error: event.error.toString(),
    ));
  }

  /// Handle job cancellation.
  @override
  void onActiveCancelled(JobCancelledEvent event) {
    // Silently handle cancellation - just reset loading states
    emit(state.copyWith(isLoading: false, isSearching: false));
  }

  /// Handle job retry.
  @override
  void onJobRetrying(JobRetryingEvent event) {
    // Log retry for debugging
    // In production, you might show a toast or update UI
  }

  // ============ HELPERS ============

  List<Task> _updateTaskInList(List<Task> tasks, Task updatedTask) {
    final index = tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index >= 0) {
      return [...tasks]
        ..[index] = updatedTask;
    }
    return [...tasks, updatedTask];
  }

  @override
  Future<void> close() {
    _fetchToken?.cancel();
    _searchToken?.cancel();
    return super.close();
  }
}

