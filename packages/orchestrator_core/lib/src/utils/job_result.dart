import 'dart:async';

/// Result type for job execution - either success or failure.
///
/// This provides a cleaner API than using try-catch or checking event types.
///
/// Example:
/// ```dart
/// final handle = orchestrator.dispatch<User>(FetchUserJob());
/// try {
///   final result = await handle.future;
///   print('Got: ${result.data}');
/// } catch (e) {
///   print('Failed: $e');
/// }
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
