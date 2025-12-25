import 'package:orchestrator_bloc/orchestrator_bloc.dart';

/// Jobs for the orchestrator approach.

class FetchTasksJob extends BaseJob {
  FetchTasksJob({super.cancellationToken, super.retryPolicy})
      : super(id: generateJobId('fetch-tasks'));
}

class SearchTasksJob extends BaseJob {
  final String query;
  SearchTasksJob(this.query, {super.cancellationToken})
      : super(id: generateJobId('search'));
}

class FetchCategoriesJob extends BaseJob {
  FetchCategoriesJob() : super(id: generateJobId('categories'));
}

class FetchStatsJob extends BaseJob {
  FetchStatsJob() : super(id: generateJobId('stats'));
}
