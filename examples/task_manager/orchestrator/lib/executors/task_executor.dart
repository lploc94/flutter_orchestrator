import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import 'package:shared/shared.dart';
import '../jobs/task_jobs.dart';

// ============ Individual Executors for each Job Type ============
// This pattern provides type safety and clean separation

/// Executor for fetching all tasks.
class FetchTasksExecutor extends BaseExecutor<FetchTasksJob> {
  final MockApiService _api;
  FetchTasksExecutor(this._api);

  @override
  Future<List<Task>> process(FetchTasksJob job) async {
    job.cancellationToken?.throwIfCancelled();
    final tasks = await _api.fetchTasks();
    job.cancellationToken?.throwIfCancelled();
    return tasks;
  }
}

/// Executor for searching tasks.
class SearchTasksExecutor extends BaseExecutor<SearchTasksJob> {
  final MockApiService _api;
  SearchTasksExecutor(this._api);

  @override
  Future<List<Task>> process(SearchTasksJob job) async {
    job.cancellationToken?.throwIfCancelled();
    if (job.query.isEmpty) {
      return await _api.fetchTasks();
    }
    final results = await _api.searchTasks(job.query);
    job.cancellationToken?.throwIfCancelled();
    return results;
  }
}

/// Executor for creating tasks.
class CreateTaskExecutor extends BaseExecutor<CreateTaskJob> {
  final MockApiService _api;
  CreateTaskExecutor(this._api);

  @override
  Future<Task> process(CreateTaskJob job) async {
    final task = Task(
      id: '',
      title: job.title,
      description: job.description,
      categoryId: job.categoryId,
      createdAt: DateTime.now(),
    );
    return await _api.createTask(task);
  }
}

/// Executor for updating tasks.
class UpdateTaskExecutor extends BaseExecutor<UpdateTaskJob> {
  final MockApiService _api;
  UpdateTaskExecutor(this._api);

  @override
  Future<Task> process(UpdateTaskJob job) async {
    final tasks = await _api.fetchTasks();
    final existingTask = tasks.firstWhere(
      (t) => t.id == job.taskId,
      orElse: () => throw Exception('Task not found: ${job.taskId}'),
    );
    final updatedTask = existingTask.copyWith(
      title: job.title,
      description: job.description,
      categoryId: job.categoryId,
      status: job.status != null ? TaskStatus.values.byName(job.status!) : null,
      priority: job.priority != null ? TaskPriority.values.byName(job.priority!) : null,
    );
    return await _api.updateTask(updatedTask);
  }
}

/// Executor for deleting tasks.
class DeleteTaskExecutor extends BaseExecutor<DeleteTaskJob> {
  final MockApiService _api;
  DeleteTaskExecutor(this._api);

  @override
  Future<void> process(DeleteTaskJob job) async {
    await _api.deleteTask(job.taskId);
  }
}

/// Executor for fetching categories.
class FetchCategoriesExecutor extends BaseExecutor<FetchCategoriesJob> {
  final MockApiService _api;
  FetchCategoriesExecutor(this._api);

  @override
  Future<List<Category>> process(FetchCategoriesJob job) async {
    return await _api.fetchCategories();
  }
}

/// Executor for fetching stats.
class FetchStatsExecutor extends BaseExecutor<FetchStatsJob> {
  final MockApiService _api;
  FetchStatsExecutor(this._api);

  @override
  Future<DashboardStats> process(FetchStatsJob job) async {
    return await _api.fetchDashboardStats();
  }
}

