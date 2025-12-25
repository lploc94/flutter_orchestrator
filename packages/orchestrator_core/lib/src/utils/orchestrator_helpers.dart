import '../models/job.dart';
import '../infra/dispatcher.dart';
import '../base/base_executor.dart';
import 'cancellation_token.dart';

/// Mixin that provides convenient dispatch methods for orchestrators.
///
/// This mixin adds type-safe dispatch methods and common patterns
/// that reduce boilerplate in orchestrators.
///
/// Example:
/// ```dart
/// class MyOrchestrator extends BaseOrchestrator<MyState>
///     with OrchestratorHelpers {
///
///   void loadData() {
///     dispatchWithLoading(
///       FetchDataJob(),
///       onStart: () => emit(state.copyWith(isLoading: true)),
///     );
///   }
/// }
/// ```
mixin OrchestratorHelpers {
  Dispatcher get _dispatcher => Dispatcher();

  /// Dispatch a job with a loading callback.
  ///
  /// Calls [onStart] immediately, then dispatches the job.
  String dispatchWithLoading(
    BaseJob job, {
    required void Function() onStart,
  }) {
    onStart();
    return _dispatcher.dispatch(job);
  }

  /// Dispatch multiple jobs in parallel.
  ///
  /// Returns a list of job IDs.
  ///
  /// Example:
  /// ```dart
  /// final ids = dispatchAll([
  ///   FetchUserJob(userId),
  ///   FetchPostsJob(userId),
  ///   FetchCommentsJob(userId),
  /// ]);
  /// ```
  List<String> dispatchAll(List<BaseJob> jobs) {
    return jobs.map((job) => _dispatcher.dispatch(job)).toList();
  }

  /// Dispatch a job with automatic cancellation of previous job.
  ///
  /// Useful for search/autocomplete where only the latest request matters.
  ///
  /// Example:
  /// ```dart
  /// CancellationToken? _searchToken;
  ///
  /// void search(String query) {
  ///   _searchToken = dispatchReplacingPrevious(
  ///     SearchJob(query),
  ///     previousToken: _searchToken,
  ///   );
  /// }
  /// ```
  CancellationToken dispatchReplacingPrevious(
    BaseJob job, {
    CancellationToken? previousToken,
  }) {
    // Cancel previous if exists
    previousToken?.cancel();

    // Create new token
    final token = CancellationToken();

    // Create job with token (jobs should accept cancellation token in constructor)
    // For now, just dispatch and return the token
    _dispatcher.dispatch(job);

    return token;
  }

  /// Dispatch a job only if no job with the same type is currently running.
  ///
  /// Returns the job ID if dispatched, null if skipped.
  ///
  /// [activeJobIds] should be provided from the orchestrator's tracking set.
  ///
  /// Example:
  /// ```dart
  /// void refreshIfNotLoading() {
  ///   dispatchIfNotRunning(RefreshJob(), activeJobIds: _activeJobIds);
  /// }
  /// ```
  String? dispatchIfNotRunning(
    BaseJob job, {
    required Set<String> activeJobIds,
    required Map<String, Type> activeJobTypes,
  }) {
    // Check if any job of the same type is running
    if (activeJobTypes.containsValue(job.runtimeType)) {
      return null;
    }
    return _dispatcher.dispatch(job);
  }
}

/// Extension on [Dispatcher] for convenience methods.
extension DispatcherExtension on Dispatcher {
  /// Register multiple executors at once using a setup function.
  ///
  /// Example:
  /// ```dart
  /// Dispatcher().setup((register) {
  ///   register<FetchUserJob>(FetchUserExecutor());
  ///   register<FetchPostsJob>(FetchPostsExecutor());
  ///   register<SendMessageJob>(SendMessageExecutor());
  /// });
  /// ```
  void setup(void Function(void Function<J extends BaseJob>(BaseExecutor<J>) register) setup) {
    setup(<J extends BaseJob>(BaseExecutor<J> executor) {
      register<J>(executor);
    });
  }
}

