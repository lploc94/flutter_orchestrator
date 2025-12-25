import 'package:shared/shared.dart';

/// State for the Task Manager.
///
/// PROBLEM: This state class tries to hold EVERYTHING.
/// In a real app, this would grow to 50+ fields.
class TaskState {
  final List<Task> tasks;
  final List<Task> filteredTasks;
  final List<Category> categories;
  final DashboardStats? stats;

  final bool isLoading;
  final bool isLoadingCategories;
  final bool isLoadingStats;
  final bool isCreating;
  final bool isDeleting;
  final bool isSearching;
  final bool isUploading;

  final String? error;
  final String? categoryError;
  final String? statsError;
  final String? createError;
  final String? deleteError;
  final String? searchError;
  final String? uploadError;

  final String searchQuery;
  final String? selectedCategoryId;
  final TaskStatus? statusFilter;

  final double uploadProgress;
  final String? uploadingTaskId;

  // For demonstrating stale state
  final DateTime? lastFetchTime;
  final int fetchCount;

  const TaskState({
    this.tasks = const [],
    this.filteredTasks = const [],
    this.categories = const [],
    this.stats,
    this.isLoading = false,
    this.isLoadingCategories = false,
    this.isLoadingStats = false,
    this.isCreating = false,
    this.isDeleting = false,
    this.isSearching = false,
    this.isUploading = false,
    this.error,
    this.categoryError,
    this.statsError,
    this.createError,
    this.deleteError,
    this.searchError,
    this.uploadError,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.statusFilter,
    this.uploadProgress = 0,
    this.uploadingTaskId,
    this.lastFetchTime,
    this.fetchCount = 0,
  });

  TaskState copyWith({
    List<Task>? tasks,
    List<Task>? filteredTasks,
    List<Category>? categories,
    DashboardStats? stats,
    bool? isLoading,
    bool? isLoadingCategories,
    bool? isLoadingStats,
    bool? isCreating,
    bool? isDeleting,
    bool? isSearching,
    bool? isUploading,
    String? error,
    String? categoryError,
    String? statsError,
    String? createError,
    String? deleteError,
    String? searchError,
    String? uploadError,
    String? searchQuery,
    String? selectedCategoryId,
    TaskStatus? statusFilter,
    double? uploadProgress,
    String? uploadingTaskId,
    DateTime? lastFetchTime,
    int? fetchCount,
    // Special flags to clear nullable fields
    bool clearError = false,
    bool clearCategoryError = false,
    bool clearStatsError = false,
    bool clearCreateError = false,
    bool clearDeleteError = false,
    bool clearSearchError = false,
    bool clearUploadError = false,
    bool clearSelectedCategory = false,
    bool clearStatusFilter = false,
    bool clearUploadingTaskId = false,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      isCreating: isCreating ?? this.isCreating,
      isDeleting: isDeleting ?? this.isDeleting,
      isSearching: isSearching ?? this.isSearching,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      categoryError:
          clearCategoryError ? null : (categoryError ?? this.categoryError),
      statsError: clearStatsError ? null : (statsError ?? this.statsError),
      createError: clearCreateError ? null : (createError ?? this.createError),
      deleteError: clearDeleteError ? null : (deleteError ?? this.deleteError),
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
      uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: clearSelectedCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadingTaskId: clearUploadingTaskId
          ? null
          : (uploadingTaskId ?? this.uploadingTaskId),
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      fetchCount: fetchCount ?? this.fetchCount,
    );
  }
}

