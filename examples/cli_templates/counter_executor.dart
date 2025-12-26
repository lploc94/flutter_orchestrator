// @template-name: Counter
// Golden example file for CLI template generation
// Run: dart run scripts/sync_templates.dart

import 'package:orchestrator_core/orchestrator_core.dart';

import 'counter_job.dart';

/// CounterExecutor - Processes CounterJob
///
/// Executors contain the business logic and are responsible for:
/// - Executing the actual work (API calls, database operations, etc.)
/// - Handling errors and retries
/// - Emitting progress updates
class CounterExecutor extends BaseExecutor<CounterJob> {
  // TODO: Inject dependencies via constructor
  // final ApiService _api;
  // CounterExecutor(this._api);

  @override
  Future<dynamic> process(CounterJob job) async {
    // Check for cancellation before starting
    job.cancellationToken?.throwIfCancelled();

    // TODO: Implement business logic
    // Example:
    // final result = await _api.fetchData(job.userId);
    // return result;

    throw UnimplementedError('CounterExecutor.process() not implemented');
  }
}

// Don't forget to register this executor with Dispatcher:
// dispatcher.register<CounterJob>(CounterExecutor());
