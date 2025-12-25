import 'package:orchestrator_bloc/orchestrator_bloc.dart';

/// Job to fetch all tasks.
class FetchTasksJob extends BaseJob {
  final bool forceRefresh;

  FetchTasksJob({
    this.forceRefresh = false,
    super.cancellationToken,
    super.timeout,
    super.retryPolicy,
  }) : super(id: generateJobId('fetch-tasks'));
}

/// Job to search tasks.
class SearchTasksJob extends BaseJob {
  final String query;

  SearchTasksJob(
    this.query, {
    super.cancellationToken,
    super.timeout,
  }) : super(id: generateJobId('search-tasks'));
}

/// Job to create a new task.
class CreateTaskJob extends BaseJob {
  final String title;
  final String description;
  final String categoryId;

  CreateTaskJob({
    required this.title,
    this.description = '',
    required this.categoryId,
    super.retryPolicy,
  }) : super(id: generateJobId('create-task'));
}

/// Job to update an existing task.
class UpdateTaskJob extends BaseJob {
  final String taskId;
  final String? title;
  final String? description;
  final String? categoryId;
  final String? status;
  final String? priority;

  UpdateTaskJob({
    required this.taskId,
    this.title,
    this.description,
    this.categoryId,
    this.status,
    this.priority,
  }) : super(id: generateJobId('update-task'));
}

/// Job to delete a task.
class DeleteTaskJob extends BaseJob {
  final String taskId;

  DeleteTaskJob(this.taskId) : super(id: generateJobId('delete-task'));
}

/// Job to fetch categories.
class FetchCategoriesJob extends BaseJob {
  FetchCategoriesJob() : super(id: generateJobId('fetch-categories'));
}

/// Job to fetch dashboard stats.
class FetchStatsJob extends BaseJob {
  FetchStatsJob() : super(id: generateJobId('fetch-stats'));
}

