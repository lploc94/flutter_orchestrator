import '../models/event.dart';

/// Extension methods for [JobSuccessEvent] to make data extraction easier.
extension JobSuccessEventExtension on JobSuccessEvent {
  /// Safely cast data to type [T], returning null if cast fails.
  ///
  /// Example:
  /// ```dart
  /// void onActiveSuccess(JobSuccessEvent event) {
  ///   final user = event.dataOrNull<User>();
  ///   if (user != null) {
  ///     emit(state.copyWith(user: user));
  ///   }
  /// }
  /// ```
  T? dataOrNull<T>() {
    if (data is T) return data as T;
    return null;
  }

  /// Cast data to type [T], throwing if cast fails.
  ///
  /// Use when you're certain about the data type.
  ///
  /// Example:
  /// ```dart
  /// void onActiveSuccess(JobSuccessEvent event) {
  ///   final user = event.dataOrThrow<User>();
  ///   emit(state.copyWith(user: user));
  /// }
  /// ```
  T dataOrThrow<T>() {
    if (data is T) return data as T;
    throw StateError(
      'Expected data of type $T but got ${data.runtimeType}',
    );
  }

  /// Get data with a default fallback value.
  ///
  /// Example:
  /// ```dart
  /// final count = event.dataOr<int>(0);
  /// ```
  T dataOr<T>(T defaultValue) {
    if (data is T) return data as T;
    return defaultValue;
  }

  /// Map the data to another type.
  ///
  /// Example:
  /// ```dart
  /// final userName = event.mapData<User, String>((user) => user.name);
  /// ```
  R? mapData<T, R>(R Function(T data) mapper) {
    if (data is T) return mapper(data as T);
    return null;
  }
}

/// Extension methods for [JobFailureEvent] to make error handling easier.
extension JobFailureEventExtension on JobFailureEvent {
  /// Get the error as a specific exception type.
  T? errorAs<T>() {
    if (error is T) return error as T;
    return null;
  }

  /// Check if the error is of a specific type.
  bool isError<T>() => error is T;

  /// Get a user-friendly error message.
  String get errorMessage {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}

/// Extension methods for working with lists of events.
extension EventListExtension on List<BaseEvent> {
  /// Get all success events.
  Iterable<JobSuccessEvent> get successes =>
      whereType<JobSuccessEvent>();

  /// Get all failure events.
  Iterable<JobFailureEvent> get failures =>
      whereType<JobFailureEvent>();

  /// Get all progress events.
  Iterable<JobProgressEvent> get progress =>
      whereType<JobProgressEvent>();

  /// Get events for a specific job ID.
  Iterable<BaseEvent> forJob(String jobId) =>
      where((e) => e.correlationId == jobId);

  /// Get the latest event for a job.
  BaseEvent? latestForJob(String jobId) {
    final events = forJob(jobId).toList();
    if (events.isEmpty) return null;
    return events.reduce((a, b) =>
        a.timestamp.isAfter(b.timestamp) ? a : b);
  }
}

