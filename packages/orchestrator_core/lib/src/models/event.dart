import 'package:meta/meta.dart';

/// Base class for all events in the system.
/// Events are "Fire-and-Forget" messages broadcasted by Executors.
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

// ============ Result Events ============

/// Emitted when a Job completes successfully.
class JobSuccessEvent<T> extends BaseEvent {
  final T data;
  final bool isOptimistic;

  JobSuccessEvent(super.correlationId, this.data, {this.isOptimistic = false});

  /// Safe cast helper.
  /// Returns [data] as [R] if type matches, otherwise returns null.
  /// Avoids runtime exceptions when casting generic data.
  R? dataAs<R>() {
    if (data is R) return data as R;
    return null;
  }

  @override
  String toString() =>
      'JobSuccessEvent(id: $correlationId, data: $data, optimistic: $isOptimistic)';
}

/// Emitted when a Job fails.
class JobFailureEvent extends BaseEvent {
  final Object error;
  final StackTrace? stackTrace;
  final bool wasRetried;

  JobFailureEvent(
    super.correlationId,
    this.error, [
    this.stackTrace,
    this.wasRetried = false,
  ]);

  @override
  String toString() => 'JobFailureEvent(id: $correlationId, error: $error)';
}

/// Emitted when a Job is cancelled.
class JobCancelledEvent extends BaseEvent {
  final String? reason;

  JobCancelledEvent(super.correlationId, [this.reason]);

  @override
  String toString() => 'JobCancelledEvent(id: $correlationId, reason: $reason)';
}

/// Emitted when a Job times out.
class JobTimeoutEvent extends BaseEvent {
  final Duration timeout;

  JobTimeoutEvent(super.correlationId, this.timeout);

  @override
  String toString() =>
      'JobTimeoutEvent(id: $correlationId, timeout: ${timeout.inSeconds}s)';
}

/// Emitted when data is found in cache (Unified Data Flow).
class JobCacheHitEvent<T> extends BaseEvent {
  final T data;
  JobCacheHitEvent(super.correlationId, this.data);

  @override
  String toString() => 'JobCacheHitEvent(id: $correlationId, data: $data)';
}

/// Emitted when placeholder data is available (Unified Data Flow).
class JobPlaceholderEvent<T> extends BaseEvent {
  final T data;
  JobPlaceholderEvent(super.correlationId, this.data);

  @override
  String toString() => 'JobPlaceholderEvent(id: $correlationId, data: $data)';
}

// ============ Progress Events ============

/// Emitted to report progress of a long-running job.
class JobProgressEvent extends BaseEvent {
  /// Progress value (0.0 to 1.0).
  ///
  /// Values outside this range will be clamped automatically.
  final double progress;

  /// Optional message.
  final String? message;

  /// Optional: Current step / Total steps.
  final int? currentStep;
  final int? totalSteps;

  JobProgressEvent(
    super.correlationId, {
    required double progress,
    this.message,
    this.currentStep,
    this.totalSteps,
  }) : progress = progress.clamp(0.0, 1.0) {
    assert(
      currentStep == null || totalSteps == null || currentStep! <= totalSteps!,
      'currentStep ($currentStep) cannot be greater than totalSteps ($totalSteps)',
    );
  }

  @override
  String toString() =>
      'JobProgressEvent(id: $correlationId, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

// ============ Lifecycle Events ============

/// Emitted when a Job starts executing.
class JobStartedEvent extends BaseEvent {
  final String jobType;
  JobStartedEvent(super.correlationId, {required this.jobType});

  @override
  String toString() => 'JobStartedEvent(id: $correlationId, type: $jobType)';
}

/// Emitted when a Job is retrying after failure.
class JobRetryingEvent extends BaseEvent {
  final int attempt;
  final int maxRetries;
  final Object lastError;
  final Duration delayBeforeRetry;

  JobRetryingEvent(
    super.correlationId, {
    required this.attempt,
    required this.maxRetries,
    required this.lastError,
    required this.delayBeforeRetry,
  });

  @override
  String toString() =>
      'JobRetryingEvent(id: $correlationId, attempt: $attempt/$maxRetries)';
}

// ============ Network Sync Events ============

/// Emitted when a network-queued job fails during background sync.
///
/// Orchestrators can listen to this event to:
/// - Rollback optimistic UI updates
/// - Show error notifications to user
/// - Log sync failures
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
