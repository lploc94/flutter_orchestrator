import 'dart:async';
import 'package:meta/meta.dart';
import 'data_source.dart';

/// Result returned by [JobHandle.future] containing data and its source.
///
/// This allows callers to know where the data came from:
/// - [DataSource.cached]: Data was served from cache
/// - [DataSource.fresh]: Data was fetched from the source
/// - [DataSource.optimistic]: Data was created optimistically while offline
///
/// ## Usage
///
/// ```dart
/// final handle = orchestrator.dispatch<List<User>>(LoadUsersJob());
/// final result = await handle.future;
///
/// if (result.isCached) {
///   // Show staleness indicator
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Showing cached data...')),
///   );
/// }
///
/// // Use the data
/// final users = result.data;
/// ```
class JobHandleResult<T> {
  /// The result data.
  final T data;

  /// Where the data came from.
  final DataSource source;

  const JobHandleResult({required this.data, required this.source});

  /// True if data came from cache.
  bool get isCached => source == DataSource.cached;

  /// True if data was freshly fetched.
  bool get isFresh => source == DataSource.fresh;

  /// True if data was created optimistically while offline.
  bool get isOptimistic => source == DataSource.optimistic;

  @override
  String toString() => 'JobHandleResult(data: $data, source: $source)';
}

/// Progress update from a running job.
///
/// Used with [JobHandle.progress] stream for tracking long-running operations.
///
/// ## Example
///
/// ```dart
/// final handle = orchestrator.dispatch<void>(UploadFilesJob(files));
///
/// handle.progress.listen((progress) {
///   setState(() {
///     uploadProgress = progress.value;
///     statusMessage = progress.message;
///   });
/// });
///
/// await handle.future;
/// ```
class JobProgress {
  /// Progress value from 0.0 to 1.0.
  final double value;

  /// Optional human-readable message.
  final String? message;

  /// Optional: Current step number.
  final int? currentStep;

  /// Optional: Total number of steps.
  final int? totalSteps;

  const JobProgress(
    this.value, {
    this.message,
    this.currentStep,
    this.totalSteps,
  });

  /// Progress as percentage (0-100).
  int get percentage => (value * 100).round();

  @override
  String toString() =>
      'JobProgress($percentage%${message != null ? ': $message' : ''})';
}

/// A handle to track and await a dispatched job's completion.
///
/// When you dispatch a job, you receive a [JobHandle] that allows you to:
/// - Await the job's first result (cached or fresh) via [future]
/// - Track progress via [progress] stream
/// - Check completion status via [isCompleted]
/// - Access the job ID via [jobId]
///
/// ## Basic Usage
///
/// ```dart
/// final handle = orchestrator.dispatch<List<User>>(LoadUsersJob());
/// setState(() => isLoading = true);
///
/// try {
///   final result = await handle.future;
///   // result.data contains List<User>
///   // result.source tells you if it's cached/fresh/optimistic
/// } catch (e) {
///   // Handle error
/// } finally {
///   setState(() => isLoading = false);
/// }
/// ```
///
/// ## Progress Tracking
///
/// ```dart
/// final handle = orchestrator.dispatch<void>(UploadFilesJob(files));
///
/// handle.progress.listen((p) {
///   print('Upload: ${p.percentage}% - ${p.message}');
/// });
///
/// await handle.future;
/// ```
///
/// ## SWR (Stale-While-Revalidate) Behavior
///
/// With cache + revalidate enabled:
/// 1. Handle completes immediately with cached data (result.isCached == true)
/// 2. Worker continues in background
/// 3. Fresh data emits as domain event → orchestrator state auto-updates
///
/// The caller only awaits once, UI rebuilds automatically on fresh data.
///
/// ## Fire-and-Forget Pattern
///
/// If the caller doesn't await the handle, errors are silently ignored
/// (no uncaught async errors). The orchestrator still receives events
/// via the SignalBus as usual.
class JobHandle<T> {
  /// The correlation ID of the job.
  final String jobId;

  final Completer<JobHandleResult<T>> _completer =
      Completer<JobHandleResult<T>>();
  final StreamController<JobProgress> _progressController =
      StreamController<JobProgress>.broadcast();

  /// Creates a new job handle for the given job ID.
  ///
  /// Automatically installs an error handler to prevent uncaught async errors
  /// when the caller doesn't await the future.
  JobHandle(this.jobId) {
    // Prevent uncaught async error if no one awaits this future.
    // This makes fire-and-forget dispatch safe.
    _completer.future.ignore();
  }

  /// Future that completes when the job has its first result.
  ///
  /// For cached jobs with revalidate, this completes with cached data.
  /// For non-cached jobs, this completes with the worker result.
  ///
  /// The result includes both the data and its [DataSource].
  ///
  /// If the job fails, this future completes with an error.
  /// If you don't await this future, errors are silently ignored.
  Future<JobHandleResult<T>> get future => _completer.future;

  /// Stream of progress updates from the job.
  ///
  /// This stream is broadcast (multiple listeners allowed) and will
  /// close automatically when the job completes or is disposed.
  Stream<JobProgress> get progress => _progressController.stream;

  /// Whether this handle has already been completed.
  bool get isCompleted => _completer.isCompleted;

  /// Complete the handle with a successful result.
  ///
  /// Safe to call multiple times - subsequent calls are ignored.
  /// This is important for SWR where cache completes first,
  /// then worker completes later (ignored).
  ///
  /// [data] is the result data.
  /// [source] indicates where the data came from.
  void complete(T data, DataSource source) {
    if (!_completer.isCompleted) {
      _completer.complete(JobHandleResult(data: data, source: source));
    }
  }

  /// Complete the handle with an error.
  ///
  /// Safe to call multiple times - subsequent calls are ignored.
  /// If no one awaits [future], the error is silently ignored.
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }

  /// Report progress update.
  ///
  /// Called by Executor during job processing to report progress.
  /// Progress values should be between 0.0 and 1.0.
  void reportProgress(
    double value, {
    String? message,
    int? currentStep,
    int? totalSteps,
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(JobProgress(
        value.clamp(0.0, 1.0),
        message: message,
        currentStep: currentStep,
        totalSteps: totalSteps,
      ));
    }
  }

  /// Dispose resources.
  ///
  /// This is called internally by the Executor when the job completes.
  /// It closes the progress stream.
  @internal
  void dispose() {
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }

  @override
  String toString() => 'JobHandle<$T>($jobId, completed: $isCompleted)';
}
