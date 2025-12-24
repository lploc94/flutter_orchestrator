import '../models/job.dart';
import '../base/base_executor.dart';

/// Exception thrown when no executor is found for a job.
class ExecutorNotFoundException implements Exception {
  final Type jobType;
  ExecutorNotFoundException(this.jobType);
  @override
  String toString() =>
      'ExecutorNotFoundException: No executor registered for job type $jobType';
}

/// The Router that connects Orchestrators to Executors.
/// It uses a Registry to lookup the correct Executor for a Job.
class Dispatcher {
  final Map<Type, BaseExecutor> _registry = {};

  // Singleton (Optional, but usually Dispatcher is a singleton service)
  static final Dispatcher _instance = Dispatcher._internal();
  factory Dispatcher() => _instance;
  Dispatcher._internal();

  /// Register an executor for a specific Job Type.
  void register<J extends BaseJob>(BaseExecutor<J> executor) {
    _registry[J] = executor;
  }

  /// Dispatch a job to the subscribed executor.
  /// Returns the Job ID (Correlation ID) immediately.
  String dispatch(BaseJob job) {
    final executor = _registry[job.runtimeType];

    if (executor == null) {
      throw ExecutorNotFoundException(job.runtimeType);
    }

    // Fire-and-forget execution
    // Unhandled future errors in executor should be caught inside executor.
    (executor as BaseExecutor<dynamic>).execute(job);

    return job.id;
  }

  // For testing cleanup
  void clear() {
    _registry.clear();
  }
}
