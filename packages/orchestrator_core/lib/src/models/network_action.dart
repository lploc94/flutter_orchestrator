/// Interface for jobs that require network connectivity and support offline queuing.
///
/// Jobs implementing this interface will be intercepted by the [Dispatcher].
/// If the device is offline, [createOptimisticResult] will be called immediately,
/// and the job will be serialized via [toJson] and queued for later execution.
///
/// Example:
/// ```dart
/// @NetworkJob()
/// class SendMessageJob extends BaseJob implements NetworkAction<Message> {
///   // ...
/// }
/// ```
abstract class NetworkAction<T> {
  /// Serializes the job data to a JSON map for persistence.
  ///
  /// This map will be stored in the local queue and used to reconstruct the job
  /// when connectivity is restored.
  Map<String, dynamic> toJson();

  /// Creates an optimistic result to be returned immediately when the device is offline.
  ///
  /// This allows the UI to update instantly (e.g., showing a "sending..." message)
  /// while the actual operation is queued.
  T createOptimisticResult();

  /// Optional: Unique ID for this action to handle deduplication or cancellation.
  /// If null, a UUID will be generated automatically.
  String? get deduplicationKey => null;
}
