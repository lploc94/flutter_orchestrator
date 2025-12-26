/// Annotation to simplify Job class declaration.
///
/// When applied to a class, the generator will:
/// - Create a class that extends `BaseJob`
/// - Auto-generate job ID
/// - Apply configured timeout and retry policy
///
/// Example:
/// ```dart
/// @GenerateJob(timeout: Duration(seconds: 30), maxRetries: 3)
/// class FetchUserJob {
///   final String userId;
///   FetchUserJob(this.userId);
/// }
/// ```
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
/// When applied to a class, the generator will:
/// - Create a class that extends `BaseEvent`
/// - Handle correlationId automatically
///
/// Example:
/// ```dart
/// @GenerateEvent()
/// class OrderPlaced {
///   final Order order;
///   final DateTime timestamp;
/// }
/// ```
class GenerateEvent {
  const GenerateEvent();
}
