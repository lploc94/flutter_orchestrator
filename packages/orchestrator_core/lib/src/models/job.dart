import '../utils/cancellation_token.dart';
import '../utils/retry_policy.dart';
import '../infra/signal_bus.dart';
import 'data_strategy.dart';

/// Base class for all Jobs (Commands/Intents) in the system.
/// A Job represents a "Packet of Work" sent from Orchestrator to Executor.
abstract class BaseJob {
  /// Unique ID to track this specific job instance (Correlation ID).
  final String id;

  /// Optional timeout for this job.
  final Duration? timeout;

  /// Optional cancellation token.
  final CancellationToken? cancellationToken;

  /// Optional retry policy.
  final RetryPolicy? retryPolicy;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// Context: The bus instance this job belongs to.
  /// Set by Orchestrator before dispatching.
  SignalBus? bus;

  /// Optional data strategy (Cache, Placeholder, etc).
  final DataStrategy? strategy;

  BaseJob({
    required this.id,
    this.timeout,
    this.cancellationToken,
    this.retryPolicy,
    this.metadata,
    this.strategy,
  });

  @override
  String toString() => '$runtimeType(id: $id)';
}

/// Helper to generate unique job IDs.
String generateJobId([String? prefix]) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = timestamp.hashCode.abs() % 10000;
  return '${prefix ?? 'job'}-$timestamp-$random';
}
