import 'package:shared/shared.dart';

/// State for the Task Manager using Orchestrator pattern.
///
/// KEY DIFFERENCES FROM TRADITIONAL:
/// 1. Much simpler - fewer boolean flags needed
/// 2. Using AsyncState pattern for loading/error/data
/// 3. Clear separation of concerns
class TaskState {
  final List<Task> tasks;
  final List<Task> filteredTasks;
  final List<Category> categories;
  final DashboardStats? stats;

  // Simplified loading states using job tracking
  final bool isLoading;
  final bool isSearching;
  final bool isCreating;

  final String? error;
  final String searchQuery;
  final String? selectedCategoryId;
  final TaskStatus? statusFilter;

  final DateTime? lastFetchTime;
  final int fetchCount;

  const TaskState({
    this.tasks = const [],
    this.filteredTasks = const [],
    this.categories = const [],
    this.stats,
    this.isLoading = false,
    this.isSearching = false,
    this.isCreating = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.statusFilter,
    this.lastFetchTime,
    this.fetchCount = 0,
  });

  TaskState copyWith({
    List<Task>? tasks,
    List<Task>? filteredTasks,
    List<Category>? categories,
    DashboardStats? stats,
    bool? isLoading,
    bool? isSearching,
    bool? isCreating,
    String? error,
    String? searchQuery,
    String? selectedCategoryId,
    TaskStatus? statusFilter,
    DateTime? lastFetchTime,
    int? fetchCount,
    bool clearError = false,
    bool clearSelectedCategory = false,
    bool clearStatusFilter = false,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: clearSelectedCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      fetchCount: fetchCount ?? this.fetchCount,
    );
  }
}

