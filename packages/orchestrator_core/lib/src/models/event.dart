import 'package:meta/meta.dart';

/// Base class for all events in the system.
///
/// Events are domain messages broadcasted via the [SignalBus].
/// All events have a [correlationId] linking them to the originating job.
///
/// ## Creating Domain Events
///
/// ```dart
/// class UsersLoadedEvent extends BaseEvent {
///   final List<User> users;
///   final DataSource source;
///
///   UsersLoadedEvent(super.correlationId, this.users, [this.source = DataSource.fresh]);
/// }
/// ```
@immutable
abstract class BaseEvent {
  /// ID of the Job that generated this event (Correlation ID).
  final String correlationId;

  /// Timestamp when the event was emitted.
  final DateTime timestamp;

  BaseEvent(this.correlationId) : timestamp = DateTime.now();

  @override
  String toString() => '$runtimeType(id: $correlationId)';
}

// ============ Network Sync Events ============

/// Emitted when a network-queued job fails during background sync.
///
/// Orchestrators can listen to this event to:
/// - Rollback optimistic UI updates
/// - Show error notifications to user
/// - Log sync failures
///
/// Note: This event is kept as it's useful for offline-first apps.
/// Consider defining your own domain event for more specific handling.
class NetworkSyncFailureEvent extends BaseEvent {
  /// The error that caused the sync failure.
  final Object error;

  /// Stack trace of the error.
  final StackTrace? stackTrace;

  /// Number of times this job has been retried.
  final int retryCount;

  /// If true, this job has exceeded max retries and will be abandoned.
  /// Orchestrators should treat this as a permanent failure.
  final bool isPoisoned;

  NetworkSyncFailureEvent(
    super.correlationId, {
    required this.error,
    this.stackTrace,
    required this.retryCount,
    required this.isPoisoned,
  });

  @override
  String toString() =>
      'NetworkSyncFailureEvent(id: $correlationId, retry: $retryCount, poisoned: $isPoisoned)';
}

// ============ DevTools Events ============

/// Emitted to update the Executor Registry in DevTools.
class ExecutorRegistryEvent extends BaseEvent {
  /// Map of Job Type Name -> Executor Type Name
  final Map<String, String> registry;

  ExecutorRegistryEvent(this.registry) : super('system_registry_event');

  @override
  String toString() => 'ExecutorRegistryEvent(count: ${registry.length})';
}
