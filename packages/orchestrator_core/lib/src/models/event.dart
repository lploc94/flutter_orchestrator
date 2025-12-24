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
  JobSuccessEvent(super.correlationId, this.data);

  /// Safe cast helper.
  /// Returns [data] as [R] if type matches, otherwise returns null.
  /// Avoids runtime exceptions when casting generic data.
  R? dataAs<R>() {
    if (data is R) return data as R;
    return null;
  }

  @override
  String toString() => 'JobSuccessEvent(id: $correlationId, data: $data)';
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

// ============ Progress Events ============

/// Emitted to report progress of a long-running job.
class JobProgressEvent extends BaseEvent {
  /// Progress value (0.0 to 1.0).
  final double progress;

  /// Optional message.
  final String? message;

  /// Optional: Current step / Total steps.
  final int? currentStep;
  final int? totalSteps;

  JobProgressEvent(
    super.correlationId, {
    required this.progress,
    this.message,
    this.currentStep,
    this.totalSteps,
  });

  @override
  String toString() =>
      'JobProgressEvent(id: $correlationId, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

// ============ Lifecycle Events ============

/// Emitted when a Job starts executing.
class JobStartedEvent extends BaseEvent {
  JobStartedEvent(super.correlationId);
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
