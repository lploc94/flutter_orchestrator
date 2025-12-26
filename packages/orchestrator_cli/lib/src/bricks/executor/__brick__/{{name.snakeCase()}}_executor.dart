import 'package:orchestrator_core/orchestrator_core.dart';

import '{{name.snakeCase()}}_job.dart';

/// {{name.pascalCase()}}Executor - Processes {{name.pascalCase()}}Job
///
/// Executors contain the business logic and are responsible for:
/// - Executing the actual work (API calls, database operations, etc.)
/// - Handling errors and retries
/// - Emitting progress updates
class {{name.pascalCase()}}Executor extends BaseExecutor<{{name.pascalCase()}}Job> {
  // TODO: Inject dependencies via constructor
  // final ApiService _api;
  // {{name.pascalCase()}}Executor(this._api);

  @override
  Future<dynamic> process({{name.pascalCase()}}Job job) async {
    // Check for cancellation before starting
    job.cancellationToken?.throwIfCancelled();

    // TODO: Implement business logic
    // Example:
    // final result = await _api.fetchData(job.userId);
    // return result;

    throw UnimplementedError('{{name.pascalCase()}}Executor.process() not implemented');
  }
}

// Don't forget to register this executor with Dispatcher:
// dispatcher.register<{{name.pascalCase()}}Job>({{name.pascalCase()}}Executor());
