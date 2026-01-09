/// Annotation to simplify Job class declaration.
///
/// When applied to a class, the generator will create an abstract class
/// `_$ClassName` that:
/// - Extends `EventJob<TResult, TEvent>` with proper type parameters
/// - Auto-generates job ID with class name as prefix
/// - Applies configured timeout and retry policy
///
/// Example:
/// ```dart
/// @GenerateJob(timeout: Duration(seconds: 30), maxRetries: 3)
/// class FetchUserJob extends _$FetchUserJob {
///   final String userId;
///   FetchUserJob(this.userId);
/// }
/// ```
///
/// The generated `_$FetchUserJob` handles:
/// - `id`: Auto-generated as `fetch_user_job-<timestamp>-<random>`
/// - `timeout`: 30 seconds
/// - `retryPolicy`: 3 retries with exponential backoff
class GenerateJob {
  /// Timeout duration for this job type.
  final Duration? timeout;

  /// Maximum retry attempts.
  final int? maxRetries;

  /// Initial retry delay for exponential backoff.
  final Duration? retryDelay;

  /// Job ID prefix (default: class name in snake_case).
  final String? idPrefix;

  const GenerateJob({
    this.timeout,
    this.maxRetries,
    this.retryDelay,
    this.idPrefix,
  });
}

/// Annotation to simplify Event class declaration.
///
/// When applied to a class, the generator creates:
/// - An extension with `toEvent(correlationId)` method
/// - A wrapper class that extends `BaseEvent`
///
/// Example:
/// ```dart
/// @GenerateEvent()
/// class OrderPlaced {
///   final Order order;
///   final DateTime timestamp;
///   OrderPlaced({required this.order, required this.timestamp});
/// }
/// ```
///
/// Usage after generation:
/// ```dart
/// final event = OrderPlaced(order: myOrder, timestamp: DateTime.now())
///     .toEvent(job.id);
/// bus.emit(event);
/// ```
class GenerateEvent {
  const GenerateEvent();
}
