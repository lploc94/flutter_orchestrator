import 'package:orchestrator_bloc/orchestrator_bloc.dart';
import '../shared/shared.dart';
import 'jobs.dart';

/// Executor for fetching tasks.
class FetchTasksExecutor extends BaseExecutor<FetchTasksJob> {
  final MockApi _api;

  FetchTasksExecutor(this._api);

  @override
  Future<List<Task>> process(FetchTasksJob job) async {
    job.cancellationToken?.throwIfCancelled();

    final (tasks, _, _) = await _api.fetchTasks();

    job.cancellationToken?.throwIfCancelled();
    return tasks;
  }
}

/// Executor for searching tasks.
class SearchTasksExecutor extends BaseExecutor<SearchTasksJob> {
  final MockApi _api;

  SearchTasksExecutor(this._api);

  @override
  Future<List<Task>> process(SearchTasksJob job) async {
    job.cancellationToken?.throwIfCancelled();

    if (job.query.isEmpty) {
      final (tasks, _, _) = await _api.fetchTasks();
      return tasks;
    }

    final (results, _, _, _) = await _api.searchTasks(job.query);

    job.cancellationToken?.throwIfCancelled();
    return results;
  }
}

/// Executor for fetching categories.
class FetchCategoriesExecutor extends BaseExecutor<FetchCategoriesJob> {
  final MockApi _api;

  FetchCategoriesExecutor(this._api);

  @override
  Future<List<Category>> process(FetchCategoriesJob job) async {
    return await _api.fetchCategories();
  }
}

/// Executor for fetching stats.
class FetchStatsExecutor extends BaseExecutor<FetchStatsJob> {
  final MockApi _api;

  FetchStatsExecutor(this._api);

  @override
  Future<DashboardStats> process(FetchStatsJob job) async {
    return await _api.fetchStats();
  }
}
