import 'dart:async';
import '../models/event.dart';
import '../infra/signal_bus.dart';

/// Result type for job execution - either success or failure.
///
/// This provides a cleaner API than using try-catch or checking event types.
///
/// Example:
/// ```dart
/// final result = await JobResult.fromBus(bus, jobId);
/// result.when(
///   success: (data) => print('Got: $data'),
///   failure: (error) => print('Failed: $error'),
/// );
/// ```
sealed class JobResult<T> {
  const JobResult();

  /// Create a success result.
  const factory JobResult.success(T data) = JobSuccess<T>;

  /// Create a failure result.
  const factory JobResult.failure(Object error, [StackTrace? stackTrace]) =
      JobFailure<T>;

  /// Create a cancelled result.
  const factory JobResult.cancelled([String? reason]) = JobCancelled<T>;

  /// Create a timeout result.
  const factory JobResult.timeout(Duration timeout) = JobTimeout<T>;

  /// Wait for a job to complete and return the result.
  ///
  /// Listens to the bus for the job's terminal event (success, failure,
  /// cancelled, or timeout) and returns the appropriate [JobResult].
  ///
  /// @Deprecated: Use [JobHandle.future] instead. This method relies on
  /// legacy framework events (JobSuccessEvent, JobFailureEvent, etc.)
  /// which are deprecated.
  ///
  /// **Migration:**
  /// ```dart
  /// // Before:
  /// final jobId = orchestrator.dispatch(MyJob());
  /// final result = await JobResult.fromBus<User>(bus, jobId);
  ///
  /// // After:
  /// final handle = orchestrator.dispatch<User>(MyJob());
  /// try {
  ///   final result = await handle.future;
  ///   // result.data is User, result.source is DataSource
  /// } catch (e) {
  ///   // Handle error
  /// }
  /// ```
  @Deprecated('Use JobHandle.future instead. Will be removed in v2.0.0')
  static Future<JobResult<T>> fromBus<T>(
    SignalBus bus,
    String jobId, {
    Duration? timeout,
  }) async {
    final completer = Completer<JobResult<T>>();

    StreamSubscription? subscription;
    Timer? timeoutTimer;

    void complete(JobResult<T> result) {
      if (!completer.isCompleted) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete(result);
      }
    }

    subscription = bus.stream.listen((event) {
      if (event.correlationId != jobId) return;

      if (event is JobSuccessEvent) {
        if (event.data is T) {
          complete(JobResult.success(event.data as T));
        } else {
          complete(JobResult.failure(
            TypeError(),
            StackTrace.current,
          ));
        }
      } else if (event is JobFailureEvent) {
        complete(JobResult.failure(event.error, event.stackTrace));
      } else if (event is JobCancelledEvent) {
        complete(JobResult.cancelled(event.reason));
      } else if (event is JobTimeoutEvent) {
        complete(JobResult.timeout(event.timeout));
      }
    });

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        complete(JobResult.timeout(timeout));
      });
    }

    return completer.future;
  }

  /// Pattern matching for job results.
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
  });

  /// Pattern matching with a default case for non-success results.
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
    required R Function() orElse,
  });

  /// Whether this is a success result.
  bool get isSuccess => this is JobSuccess<T>;

  /// Whether this is a failure result.
  bool get isFailure => this is JobFailure<T>;

  /// Get data if success, null otherwise.
  T? get dataOrNull;

  /// Get error if failure, null otherwise.
  Object? get errorOrNull;
}

/// Success result containing data.
final class JobSuccess<T> extends JobResult<T> {
  final T data;
  const JobSuccess(this.data);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
  }) =>
      success(data);

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
    required R Function() orElse,
  }) =>
      success?.call(data) ?? orElse();

  @override
  T? get dataOrNull => data;

  @override
  Object? get errorOrNull => null;
}

/// Failure result containing error.
final class JobFailure<T> extends JobResult<T> {
  final Object error;
  final StackTrace? stackTrace;
  const JobFailure(this.error, [this.stackTrace]);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
  }) =>
      failure(error, stackTrace);

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
    required R Function() orElse,
  }) =>
      failure?.call(error, stackTrace) ?? orElse();

  @override
  T? get dataOrNull => null;

  @override
  Object? get errorOrNull => error;
}

/// Cancelled result.
final class JobCancelled<T> extends JobResult<T> {
  final String? reason;
  const JobCancelled([this.reason]);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
  }) =>
      cancelled?.call(reason) ??
      failure(
        StateError('Job was cancelled${reason != null ? ': $reason' : ''}'),
        null,
      );

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
    required R Function() orElse,
  }) =>
      cancelled?.call(reason) ?? orElse();

  @override
  T? get dataOrNull => null;

  @override
  Object? get errorOrNull => null;
}

/// Timeout result.
final class JobTimeout<T> extends JobResult<T> {
  final Duration duration;
  const JobTimeout(this.duration);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
  }) =>
      timeout?.call(duration) ??
      failure(
        TimeoutException('Job timed out after ${duration.inSeconds}s'),
        null,
      );

  @override
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? failure,
    R Function(String? reason)? cancelled,
    R Function(Duration timeout)? timeout,
    required R Function() orElse,
  }) =>
      timeout?.call(duration) ?? orElse();

  @override
  T? get dataOrNull => null;

  @override
  Object? get errorOrNull => null;
}
